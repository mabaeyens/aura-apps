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

    /// Runs the two-call model for `path` where the payload is a plain-text bulletin
    /// (the normalized `prediccion/{ambito}/{dia}/{area}` products) rather than JSON.
    /// AEMET serves these as UTF-8; falls back to Latin-1 for any legacy endpoint.
    public func fetchText(_ path: String) async throws -> String {
        let envelope = try await requestEnvelope(path: path)
        guard let datos = envelope.datos, let url = URL(string: datos) else {
            throw ClientError.aemetStatus(envelope.estado ?? -1, envelope.descripcion ?? "no datos url")
        }
        let data = try await fetchData(url: url)
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .isoLatin1) { return text }
        throw ClientError.decoding("text payload: undecodable")
    }

    /// Runs the two-call model for `path` and returns the raw payload bytes (for binary products
    /// like the avisos `.tar`).
    public func fetchBinary(_ path: String) async throws -> Data {
        let envelope = try await requestEnvelope(path: path)
        guard let datos = envelope.datos, let url = URL(string: datos) else {
            throw ClientError.aemetStatus(envelope.estado ?? -1, envelope.descripcion ?? "no datos url")
        }
        return try await fetchData(url: url)
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

    /// Hourly forecast for an INE municipality code — powers the "now" reading and the hourly strip.
    func municipioHoraria(_ ine: String) async throws -> MunicipioHourly {
        let list = try await fetch("/prediccion/especifica/municipio/horaria/\(ine)",
                                   as: [MunicipioHourly].self)
        guard let first = list.first else { throw ClientError.decoding("empty hourly array") }
        return first
    }

    /// Forecast daily-max UV index for every provincial capital, in one call. `dia` 0 = today … 4.
    /// One fetch serves every location; resolve per location by INE with `UVIndex.pick(ine:in:)`. The
    /// payload is a single JSON object (not the array most `/prediccion` products use).
    func uviCities(dia: Int = 0) async throws -> [UVIForecast.City] {
        try await fetch("/prediccion/especifica/uvi/\(dia)", as: UVIForecast.self).ciudad
    }

    /// Every conventional station's recent surface observations, in one call. Large (thousands of
    /// records), so fetch it once per refresh and resolve the nearest station per location locally
    /// via `StationObservation.nearest(toLatitude:longitude:in:)`.
    func observacionTodas() async throws -> [StationObservation] {
        try await fetch("/observacion/convencional/todas", as: [StationObservation].self)
    }

    /// Active meteorological warnings for an AEMET avisos area (a `.tar` of CAP-XML files). `area`
    /// is a two-digit community code (`AvisoArea.forProvincia`). Filter to a location by province.
    func avisos(area: String) async throws -> [WeatherAlert] {
        let tar = try await fetchBinary("/avisos_cap/ultimoelaborado/area/\(area)")
        return TarReader.files(from: tar)
            .filter { $0.name.hasSuffix(".xml") }
            .flatMap { CAPParser.parse($0.body) }
    }

    /// Raw text of the community `hoy` product. `ccaa` is AEMET's community code (e.g. "mad").
    /// Note: `hoy` is amendment-only (re-issued only on significant intraday change), so this can
    /// return a bulletin dated days back. For a bulletin that always covers today, use
    /// `comunidadBulletin(_:)`. Kept for diagnostics.
    func prediccionCCAAHoy(_ ccaa: String) async throws -> String {
        try await fetchText("/prediccion/ccaa/hoy/\(ccaa)")
    }

    /// Raw text of the per-province `hoy` product. `provincia` is the 2-digit INE province code
    /// (`Location.provinciaCode`). Same amendment-only caveat as `prediccionCCAAHoy`, and AEMET
    /// maintains it even less consistently. Kept for diagnostics.
    func prediccionProvinciaHoy(_ provincia: String) async throws -> String {
        try await fetchText("/prediccion/provincia/hoy/\(provincia)")
    }
}
