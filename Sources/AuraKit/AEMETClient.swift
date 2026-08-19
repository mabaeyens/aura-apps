import Foundation

/// Minimal client for the AEMET OpenData API.
///
/// AEMET uses a two-call model: the first request returns a small JSON envelope
/// containing a temporary `datos` URL, and a second request to that URL returns the
/// actual payload. The payload is served as ISO-8859-1, so it is re-encoded to UTF-8
/// before decoding. The API key is passed as the `api_key` query parameter.
public struct AEMETClient: Sendable {

    public enum ClientError: Error, Sendable {
        case missingAPIKey
        case http(Int)
        case aemetStatus(Int, String)
        case decoding(String)
        case rateLimited
    }

    private let apiKey: String
    private let session: URLSession
    private let base = "https://opendata.aemet.es/opendata/api"

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// The envelope returned by every first call.
    private struct Envelope: Decodable {
        let estado: Int?
        let descripcion: String?
        let datos: String?
        let metadatos: String?
    }

    /// Runs the full two-call model for `path` and decodes the payload as `T`.
    public func fetch<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T {
        let envelope = try await requestEnvelope(path: path)
        guard let datos = envelope.datos, let url = URL(string: datos) else {
            throw ClientError.aemetStatus(envelope.estado ?? -1, envelope.descripcion ?? "no datos url")
        }
        let data = try await fetchData(url: url)
        return try decodePayload(data, as: T.self)
    }

    private func requestEnvelope(path: String) async throws -> Envelope {
        guard !apiKey.isEmpty else { throw ClientError.missingAPIKey }
        var comps = URLComponents(string: base + path)!
        comps.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        let (data, response) = try await session.data(from: comps.url!)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 429 { throw ClientError.rateLimited }
        guard code == 200 else { throw ClientError.http(code) }
        do {
            return try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw ClientError.decoding("envelope: \(error)")
        }
    }

    private func fetchData(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw ClientError.http(code) }
        return data
    }

    /// Decode the payload. AEMET usually serves UTF-8, but some legacy endpoints send
    /// ISO-8859-1, so fall back to a Latin-1 → UTF-8 re-encode if the direct decode fails.
    private func decodePayload<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch let utf8Error {
            if let text = String(data: data, encoding: .isoLatin1),
               let reencoded = text.data(using: .utf8) {
                do {
                    return try decoder.decode(T.self, from: reencoded)
                } catch {
                    throw ClientError.decoding("payload (utf8 + latin1 both failed): \(error)")
                }
            }
            throw ClientError.decoding("payload: \(utf8Error)")
        }
    }
}

public extension AEMETClient {
    /// Daily forecast for an INE municipality code (e.g. "28079" for Madrid).
    func municipioDiaria(_ ine: String) async throws -> MunicipioForecast {
        let list = try await fetch("/prediccion/especifica/municipio/diaria/\(ine)",
                                   as: [MunicipioForecast].self)
        guard let first = list.first else { throw ClientError.decoding("empty forecast array") }
        return first
    }
}
