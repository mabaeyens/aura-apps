import Foundation

/// A nearest-station air-quality reading, from the MITECO national ICA feed (not AEMET — the OpenData
/// portal has no urban air-quality product). The índice de calidad del aire (ICA) is a 1–6 category, the
/// *worst* of the pollutants a station measures; `debido_a` names the pollutant that drove it.
///
/// Source: https://ica.miteco.es/datos/ica-ultima-hora.csv (CC-BY 4.0, MITECO). One ~50 KB national
/// download serves every location — fetch the rows once per refresh and resolve nearest locally.
/// One measured pollutant at the nearest station: its latest valid hourly concentration in µg/m³. Only
/// pollutants the station actually reports appear — a traffic station that measures only NO₂ contributes
/// a single component, never a fabricated zero for the rest.
public struct AirComponent: Codable, Sendable, Hashable {
    /// Canonical MITECO magnitud token: "NO2", "O3", "PM2.5", "PM10", "SO2".
    public let pollutant: String
    /// Latest valid hourly concentration, µg/m³.
    public let value: Double

    public init(pollutant: String, value: Double) {
        self.pollutant = pollutant
        self.value = value
    }

    /// Display order for the breakdown, mirroring the official ICA listing.
    static let order = ["NO2", "O3", "PM2.5", "PM10", "SO2"]
    var rank: Int { Self.order.firstIndex(of: pollutant) ?? Self.order.count }

    /// Subscripted label, e.g. "NO₂", "O₃", "PM2,5".
    public var label: String {
        switch pollutant {
        case "O3":    return "O₃"
        case "NO2":   return "NO₂"
        case "SO2":   return "SO₂"
        case "PM2.5": return "PM2,5"
        case "PM10":  return "PM10"
        default:      return pollutant
        }
    }

    /// The value with Spanish decimal comma, e.g. "3,5" or "27".
    public var valueText: String {
        value == value.rounded()
            ? String(Int(value.rounded()))
            : String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}

public struct AirQuality: Codable, Sendable, Hashable {
    /// ICA category 1…6 (1 buena … 6 extremadamente desfavorable). No-data is represented as `nil`
    /// `AirQuality`, so this is always a real category.
    public let category: Int
    /// True when MITECO computed the category from fewer pollutants than the station can measure (the raw
    /// índice arrived as category × 10). The category still stands — it's just lower-confidence.
    public let partial: Bool
    /// Dominant pollutant driving the category ("O3", "NO2", "PM2.5", "PM10", "SO2"), or nil if unlisted.
    public let pollutant: String?
    /// The station the reading came from, and how far it sits from the location (km).
    public let station: String
    public let distanceKm: Double
    /// Measurement instant (UTC in the feed).
    public let measured: Date
    /// Per-pollutant breakdown for the same station, from MITECO's backend (empty when unavailable).
    /// Sorted in the canonical `AirComponent.order`; only actually-measured pollutants are present.
    public let components: [AirComponent]

    public init(category: Int, partial: Bool, pollutant: String?,
                station: String, distanceKm: Double, measured: Date,
                components: [AirComponent] = []) {
        self.category = category
        self.partial = partial
        self.pollutant = pollutant
        self.station = station
        self.distanceKm = distanceKm
        self.measured = measured
        self.components = components.sorted { $0.rank < $1.rank }
    }

    /// A copy with the per-pollutant breakdown attached (headline fields unchanged).
    public func adding(components: [AirComponent]) -> AirQuality {
        AirQuality(category: category, partial: partial, pollutant: pollutant,
                   station: station, distanceKm: distanceKm, measured: measured,
                   components: components)
    }

    /// Spanish ICA category name (the official six-level scale).
    public var categoryName: String {
        switch category {
        case 1: return "Buena"
        case 2: return "Razonablemente buena"
        case 3: return "Regular"
        case 4: return "Desfavorable"
        case 5: return "Muy desfavorable"
        case 6: return "Extremadamente desfavorable"
        default: return "Sin datos"
        }
    }

    /// Dominant pollutant with proper subscripts/formatting, e.g. "O₃", "NO₂", "PM2,5".
    public var pollutantLabel: String? {
        switch pollutant {
        case "O3":    return "O₃"
        case "NO2":   return "NO₂"
        case "SO2":   return "SO₂"
        case "PM2.5": return "PM2,5"
        case "PM10":  return "PM10"
        case let other?: return other.isEmpty ? nil : other
        default:      return nil
        }
    }
}

/// Downloads and parses the MITECO national ICA feed and resolves the nearest active station.
public enum MitecoAirQuality {
    public static let feedURL = URL(string: "https://ica.miteco.es/datos/ica-ultima-hora.csv")!

    /// The undocumented ICA backend that serves the per-pollutant breakdown the CSV lacks. Reached with a
    /// single named query per nearest station; see `components(toLatitude:…)`.
    static let backendURL = URL(string: "https://backend.ica.miteco.es/sgca/")!

    /// One parsed row of the national feed (only active stations with a real category are kept).
    public struct Station: Sendable, Hashable {
        public let code: Int            // cod_estacion — keys the backend per-pollutant query
        public let name: String
        public let latitude: Double
        public let longitude: Double
        public let indice: Int          // raw feed code: 1–6, or category×10 (partial), never 0 here
        public let pollutant: String?
        public let measured: Date
    }

    /// Fetch the whole national feed once (nearest is resolved locally per location). Returns an empty
    /// array — never throws — if the feed is unreachable or non-200, so a miteco outage never blocks the
    /// AEMET refresh.
    public static func stations(session: URLSession = .shared) async -> [Station] {
        do {
            let (data, response) = try await session.data(from: feedURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            return parse(String(decoding: data, as: UTF8.self))
        } catch {
            return []
        }
    }

    /// The nearest active station to a point, or nil if none is usable.
    static func nearestStation(toLatitude lat: Double, longitude lon: Double,
                               in stations: [Station]) -> (station: Station, km: Double)? {
        var best: (station: Station, km: Double)?
        for s in stations {
            let km = haversine(lat, lon, s.latitude, s.longitude)
            if best == nil || km < best!.km { best = (s, km) }
        }
        return best
    }

    /// The nearest active station to a point, as an `AirQuality`, or nil if none is usable.
    public static func nearest(toLatitude lat: Double, longitude lon: Double,
                               in stations: [Station]) -> AirQuality? {
        guard let (s, km) = nearestStation(toLatitude: lat, longitude: lon, in: stations) else { return nil }
        let partial = s.indice >= 10
        let category = partial ? s.indice / 10 : s.indice
        guard (1...6).contains(category) else { return nil }
        return AirQuality(category: category, partial: partial, pollutant: s.pollutant,
                          station: prettyName(s.name), distanceKm: km, measured: s.measured)
    }

    /// The per-pollutant breakdown for the nearest station: its latest valid hourly concentration for
    /// each measured pollutant. One POST to the undocumented ICA backend (`sql1#code#start#end`). Returns
    /// an empty array — never throws — on any failure, so the headline card still stands without it.
    public static func components(toLatitude lat: Double, longitude lon: Double,
                                  in stations: [Station], session: URLSession = .shared) async -> [AirComponent] {
        guard let (s, _) = nearestStation(toLatitude: lat, longitude: lon, in: stations) else { return [] }
        // Query the whole UTC day the reading belongs to; the latest valid hour per pollutant is picked
        // locally, so a partly-filled day (early morning) still yields whatever has been measured.
        let day = backendDay.string(from: s.measured)
        guard let body = requestBody(code: s.code, day: day) else { return [] }
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            return parseComponents(data)
        } catch {
            return []
        }
    }

    /// The `application/x-www-form-urlencoded` body for the `sql1` query. Only the *value* is percent-
    /// encoded (the '#', space and ':' must be escaped); the "sql=" separator stays literal — encoding it
    /// too turns '=' into %3D, the backend then sees no parameter and answers "Consulta incorrecta".
    static func requestBody(code: Int, day: String) -> Data? {
        let sql = "sql1#\(code)#\(day) 00:00#\(day) 23:00"
        guard let value = sql.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return Data("sql=\(value)".utf8)
    }

    /// One hourly reading row from the backend `sql1` query. `valor_medido` is the raw hourly
    /// concentration (populated for every pollutant the station reports, unlike the sparse moving average);
    /// `dato_medido` flags it as validated.
    private struct Reading: Decodable {
        let hora: Int
        let magnitud: String
        let valor_medido: Double?
        let dato_medido: Bool
    }

    /// Latest validated `valor_medido` per pollutant; unmeasured pollutants are omitted (no fabricated
    /// zeros). Canonical ordering is applied by `AirQuality.init`.
    static func parseComponents(_ data: Data) -> [AirComponent] {
        guard let rows = try? JSONDecoder().decode([Reading].self, from: data) else { return [] }
        var latest: [String: Reading] = [:]
        for r in rows where r.valor_medido != nil && r.dato_medido {
            if let existing = latest[r.magnitud], existing.hora >= r.hora { continue }
            latest[r.magnitud] = r
        }
        return latest.compactMap { _, r in r.valor_medido.map { AirComponent(pollutant: r.magnitud, value: $0) } }
    }

    private static let backendDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    // MARK: - CSV

    /// Columns: cod_estacion,nombre,tipo,latitud,longitud,activa,fecha,indice,debido_a (UTF-8, comma).
    /// Drops inactive stations and índice 0 (no data). `debido_a` is a bare token in the last-hour feed
    /// (a quoted list only appears in forecast files), so a naïve comma split is safe here.
    static func parse(_ csv: String) -> [Station] {
        var out: [Station] = []
        for line in csv.split(whereSeparator: \.isNewline).dropFirst() {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 9,
                  f[5] == "true",                                   // activa
                  let code = Int(f[0]),                             // cod_estacion
                  let lat = Double(f[3]), let lon = Double(f[4]),
                  let indice = Int(f[7]), indice != 0 else { continue }
            let poll = f[8].trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            out.append(Station(code: code, name: f[1], latitude: lat, longitude: lon, indice: indice,
                               pollutant: poll.isEmpty ? nil : poll,
                               measured: parseDate(f[6]) ?? Date()))
        }
        return out
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()
    private static func parseDate(_ s: String) -> Date? { dateFormatter.date(from: s) }

    /// Feed station names are ALL CAPS ("PLAZA DEL CARMEN"); title-case them for display.
    private static func prettyName(_ raw: String) -> String {
        raw.capitalized(with: Locale(identifier: "es_ES"))
    }

    /// Great-circle distance in km.
    private static func haversine(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6371.0, p = Double.pi / 180
        let dLat = (lat2 - lat1) * p, dLon = (lon2 - lon1) * p
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * p) * cos(lat2 * p) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}
