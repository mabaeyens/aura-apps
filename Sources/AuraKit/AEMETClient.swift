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
        case invalidParameter(String)
    }

    private let apiKey: String
    private let session: URLSession
    private let base = "https://opendata.aemet.es/opendata/api"

    /// The key rides in the `api_key` query parameter (AEMET's only supported scheme), so these requests
    /// must never be cached: a persistent `URLCache` writes the key-bearing URL into `Cache.db` on disk.
    /// This ephemeral session keeps no on-disk cache, cookies, or credential store.
    private static let uncachedSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    public init(apiKey: String, session: URLSession? = nil) {
        self.apiKey = apiKey
        self.session = session ?? AEMETClient.uncachedSession
    }

    /// Rejects any path component that isn't a plain ASCII-alphanumeric code. Every AEMET path segment
    /// Aura builds — INE municipality, province, avisos area, radar site, community — is a short
    /// alphanumeric identifier drawn from a bundled catalog. Validating here means a future free-text
    /// location search can never smuggle a crafted `../`, query string, or path separator into the URL.
    static func validCode(_ s: String, length: Int? = nil) -> Bool {
        guard !s.isEmpty, s.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return false }
        if let length { return s.count == length }
        return true
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
        let data = try await perform(comps.url!)
        do {
            return try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw ClientError.decoding("envelope: \(error)")
        }
    }

    private func fetchData(url: URL) async throws -> Data {
        try await perform(url)
    }

    /// Performs one GET, paced through the shared limiter and retried on a 429 with exponential
    /// backoff. Both AEMET calls in the two-step model funnel through here, so every product —
    /// envelope and `datos` payload alike — counts against the same per-key budget. Returns the
    /// body on 200; throws `.rateLimited` after exhausting retries, `.http(code)` for anything else.
    private func perform(_ url: URL) async throws -> Data {
        var attempt = 0
        while true {
            try await RequestPacer.shared.waitForSlot()
            let (data, response) = try await session.data(from: url)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200 { return data }
            if code == 429, attempt < 2 {
                attempt += 1
                let backoff = pow(2.0, Double(attempt))   // 2 s, then 4 s
                // Propagate cancellation (`try`, not `try?`): a request cancelled mid-backoff must stop
                // retrying, not swallow the CancellationError and loop again.
                try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                continue
            }
            if code == 429 { throw ClientError.rateLimited }
            throw ClientError.http(code)
        }
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
        guard AEMETClient.validCode(ine, length: 5) else { throw ClientError.invalidParameter("ine=\(ine)") }
        let list = try await fetch("/prediccion/especifica/municipio/diaria/\(ine)",
                                   as: [MunicipioForecast].self)
        guard let first = list.first else { throw ClientError.decoding("empty forecast array") }
        return first
    }

    /// Hourly forecast for an INE municipality code — powers the "now" reading and the hourly strip.
    func municipioHoraria(_ ine: String) async throws -> MunicipioHourly {
        guard AEMETClient.validCode(ine, length: 5) else { throw ClientError.invalidParameter("ine=\(ine)") }
        let list = try await fetch("/prediccion/especifica/municipio/horaria/\(ine)",
                                   as: [MunicipioHourly].self)
        guard let first = list.first else { throw ClientError.decoding("empty hourly array") }
        return first
    }

    /// The latest regional radar image (a ~240 km-radius reflectivity frame centred on the radar site).
    /// Raw image bytes (GIF/PNG); pick the site with `RadarSite.nearest(...)`. Updates every ~10 min.
    func radarRegional(_ code: String) async throws -> Data {
        guard AEMETClient.validCode(code) else { throw ClientError.invalidParameter("radar=\(code)") }
        return try await fetchBinary("/red/radar/regional/\(code)")
    }

    /// The latest surface analysis chart (análisis de superficie / mapa de frentes): isobars, high and
    /// low pressure centres, and fronts over Europe and the North Atlantic. Raw image bytes (a single
    /// non-animated GIF, stored rotated 90° counter-clockwise). Reissued every ~12 hours (00/12 UTC).
    func surfaceAnalysis() async throws -> Data {
        return try await fetchBinary("/mapasygraficos/analisis")
    }

    /// Forecast daily-max UV index for every provincial capital, in one call. `dia` 0 = today … 4.
    /// One fetch serves every location; resolve per location by INE with `UVIndex.pick(ine:in:)`. The
    /// payload is a single JSON object (not the array most `/prediccion` products use).
    func uviCities(dia: Int = 0) async throws -> [UVIForecast.City] {
        guard (0...6).contains(dia) else { throw ClientError.invalidParameter("dia=\(dia)") }
        return try await fetch("/prediccion/especifica/uvi/\(dia)", as: UVIForecast.self).ciudad
    }

    /// Every conventional station's recent surface observations, in one call. Large (thousands of
    /// records), so fetch it once per refresh and resolve the nearest station per location locally
    /// via `StationObservation.nearest(toLatitude:longitude:in:)`.
    func observacionTodas() async throws -> [StationObservation] {
        try await fetch("/observacion/convencional/todas", as: [StationObservation].self)
    }

    /// AEMET's keyless observation RSS notifier: a plain static-host GET (no `api_key`, no two-call envelope),
    /// served from `/rss/`, not the `/opendata/api` product base.
    static let observacionRSSURL = "https://opendata.aemet.es/rss/obsconv_hh_opendata_todos_RSS.xml"

    /// When AEMET last refreshed the conventional-observation dataset, from the keyless RSS notifier
    /// (`observacionRSSURL`), or nil when the feed is unreachable or unparseable. One cheap keyless GET (still
    /// paced and 429-backed-off through `perform`, counting against the shared per-key budget) so the refresh
    /// path can decide whether the far larger keyed `observacionTodas()` download is worth making without
    /// spending a keyed request. The returned value is a publish time (~30 min past the hour), a DIFFERENT clock
    /// from the observation `fint`; never compare the two. See the unified-freshness design.
    func observacionRssUpdated() async throws -> Date? {
        guard let url = URL(string: AEMETClient.observacionRSSURL) else { return nil }
        return ObservationRSS.latestUpdate(try await perform(url))
    }

    /// Active meteorological warnings for an AEMET avisos area (a `.tar` of CAP-XML files). `area`
    /// is a two-digit community code (`AvisoArea.forProvincia`). Filter to a location by province.
    func avisos(area: String) async throws -> [WeatherAlert] {
        guard AEMETClient.validCode(area, length: 2) else { throw ClientError.invalidParameter("area=\(area)") }
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
        guard AEMETClient.validCode(ccaa) else { throw ClientError.invalidParameter("ccaa=\(ccaa)") }
        return try await fetchText("/prediccion/ccaa/hoy/\(ccaa)")
    }

    /// Raw text of the per-province `hoy` product. `provincia` is the 2-digit INE province code
    /// (`Location.provinciaCode`). Same amendment-only caveat as `prediccionCCAAHoy`, and AEMET
    /// maintains it even less consistently. Kept for diagnostics.
    func prediccionProvinciaHoy(_ provincia: String) async throws -> String {
        guard AEMETClient.validCode(provincia, length: 2) else { throw ClientError.invalidParameter("provincia=\(provincia)") }
        return try await fetchText("/prediccion/provincia/hoy/\(provincia)")
    }
}

/// Process-wide sliding-window limiter for outbound AEMET calls.
///
/// AEMET caps a key at 50 requests/minute. A single cold refresh spends ~13 calls for one location
/// and +4 per extra location (≈21 for three), plus radar on demand — comfortably under the ceiling,
/// but with no spacing a burst (many locations, or a refresh landing on top of a radar fetch) could
/// approach it. This allows bursts up to `limit` within `window` at full speed, then blocks the next
/// caller only until the oldest in-window request expires — so a normal refresh is never slowed, and
/// the limit simply cannot be tripped. `limit` sits below 50 to leave headroom.
actor RequestPacer {
    static let shared = RequestPacer()

    private let limit: Int
    private let window: TimeInterval
    private var recent: [Date] = []

    init(limit: Int = 45, window: TimeInterval = 60) {
        self.limit = limit
        self.window = window
    }

    /// Reserves the next slot, sleeping only if `limit` requests already fired inside `window`. Throws
    /// `CancellationError` if the waiting task is cancelled, so a cancelled request stops queuing instead of
    /// swallowing the cancellation and looping.
    func waitForSlot() async throws {
        while true {
            let now = Date()
            recent.removeAll { now.timeIntervalSince($0) >= window }
            if recent.count < limit {
                recent.append(now)
                return
            }
            if let oldest = recent.first {
                let wait = window - now.timeIntervalSince(oldest)
                if wait > 0 { try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            }
        }
    }
}
