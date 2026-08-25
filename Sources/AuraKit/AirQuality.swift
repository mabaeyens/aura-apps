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
    /// The ICA value in µg/m³ — the running mean the índice uses (8 h for O₃, 24 h for PM), or the last
    /// valid hour for NO₂/SO₂ where the ICA uses no average. Not the raw hourly reading for O₃/PM.
    public let value: Double
    /// The station this pollutant was read from, and how far it sits (km). Each pollutant is taken from
    /// the *nearest station that measures it*, so different pollutants can come from different stations —
    /// hence the source travels with the component, not just with the headline. Nil for legacy/preview
    /// components built without a source.
    public let station: String?
    public let distanceKm: Double?
    /// When this pollutant was measured (the reading's UTC hour). Different pollutants can carry different
    /// times, so the breakdown shows how fresh each one is. Nil when unknown.
    public let measured: Date?

    public init(pollutant: String, value: Double,
                station: String? = nil, distanceKm: Double? = nil, measured: Date? = nil) {
        self.pollutant = pollutant
        self.value = value
        self.station = station
        self.distanceKm = distanceKm
        self.measured = measured
    }

    /// Display order for the breakdown, mirroring the official ICA listing.
    static let order = ["NO2", "O3", "PM2.5", "PM10", "SO2"]
    var rank: Int { Self.order.firstIndex(of: pollutant) ?? Self.order.count }

    /// Subscripted label, e.g. "NO₂", "O₃", "PM2,5".
    public var label: String { Self.label(for: pollutant) }

    /// Subscripted label for a bare MITECO magnitud token, so a column can be rendered for a pollutant the
    /// station doesn't measure (greyed, no value) as well as for a measured one.
    public static func label(for pollutant: String) -> String {
        switch pollutant {
        case "O3":    return "O₃"
        case "NO2":   return "NO₂"
        case "SO2":   return "SO₂"
        case "PM2.5": return "PM2,5"
        case "PM10":  return "PM10"
        default:      return pollutant
        }
    }

    /// The upper µg/m³ bound of ICA categories 1…5 for a pollutant (category 6 is open-ended above the
    /// last), from the official Spanish/EEA breakpoints, or nil for a token with no scale. Shared by the
    /// band and the continuous scale position so they can't disagree.
    public static func bands(for pollutant: String) -> [Double]? {
        switch pollutant {
        case "NO2":   return [40, 90, 120, 230, 340]
        case "O3":    return [50, 100, 130, 240, 380]
        case "PM10":  return [20, 40, 50, 100, 150]
        case "PM2.5": return [10, 20, 25, 50, 75]
        case "SO2":   return [100, 200, 350, 500, 750]
        default:      return nil
        }
    }

    /// Indicative ICA band (1…6) for this pollutant's latest hourly value. It only tints the per-pollutant
    /// chip — the headline category still comes from MITECO's own índice — so the raw hourly value stands
    /// in for MITECO's moving averages (8 h for O₃, 24 h for PM). Returns 0 for an unknown token, which
    /// `Palette.airQuality` renders grey.
    public var icaCategory: Int {
        guard let bands = Self.bands(for: pollutant) else { return 0 }
        for (i, upper) in bands.enumerated() where value <= upper { return i + 1 }
        return 6
    }

    /// Where this value sits along the 1…6 scale as a continuous 0…1 fraction (for a scale-bar marker):
    /// its band index plus how far it has climbed within that band. Category 6 (above the top breakpoint)
    /// is capped near the far end. Returns 0 for a token with no scale.
    public var icaFraction: Double {
        guard let bands = Self.bands(for: pollutant) else { return 0 }
        let c = icaCategory
        let lower = c == 1 ? 0 : bands[c - 2]
        let upper = c <= 5 ? bands[c - 1] : bands[4] * 1.5     // open-ended top band: cap the climb
        let within = min(max((value - lower) / max(upper - lower, 0.0001), 0), 1)
        return (Double(c - 1) + within) / 6
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
    public var categoryName: String { Self.categoryName(category) }

    /// The official Spanish ICA name for any 1…6 category, so a per-pollutant band can be named too.
    public static func categoryName(_ category: Int) -> String {
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
            if let current = best, km >= current.km { continue }
            best = (s, km)
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

    /// The per-pollutant breakdown for a location: each pollutant taken from the *nearest active station
    /// that measures it*. The single nearest station (often urban-traffic) usually reports NO₂ and
    /// particulates but not O₃ or SO₂ — O₃ lives at background stations, SO₂ at industrial ones — so
    /// stations are probed nearest-first, one `sql1` POST each, until every pollutant is found or the
    /// search gives up (`maxStations` probed, or the next station is past `maxRadiusKm`). Each
    /// `AirComponent` carries its own station, distance and time, so a pollutant pulled from farther out
    /// is labelled as such. Never throws — an empty result just leaves the caller to fall back to the
    /// single-station índice.
    public static func breakdown(toLatitude lat: Double, longitude lon: Double, in stations: [Station],
                                 session: URLSession = .shared,
                                 maxStations: Int = 10, maxRadiusKm: Double = 80) async -> [AirComponent] {
        let sorted = stations
            .map { (station: $0, km: haversine(lat, lon, $0.latitude, $0.longitude)) }
            .sorted { $0.km < $1.km }
        let needed = Set(AirComponent.order)
        var found: [String: AirComponent] = [:]
        var probed = 0
        for entry in sorted {
            if found.count == needed.count || probed >= maxStations || entry.km > maxRadiusKm { break }
            probed += 1
            let readings = await stationReadings(entry.station, session: session)
            for (magnitud, reading) in readings where needed.contains(magnitud) && found[magnitud] == nil {
                found[magnitud] = AirComponent(pollutant: magnitud, value: reading.value,
                                               station: prettyName(entry.station.name),
                                               distanceKm: entry.km, measured: reading.date)
            }
        }
        return AirComponent.order.compactMap { found[$0] }
    }

    /// The composite ICA for a location from a per-pollutant `breakdown`: the índice is the *worst*
    /// pollutant's band — the same "peor contaminante" rule MITECO applies — but computed from each
    /// pollutant's own nearest-station ICA value, so it reflects the most recent, closest data for every
    /// pollutant rather than one station's partial coverage. That worst pollutant is the driver, and its
    /// station/distance become the headline's. Nil for an empty breakdown, so the caller can fall back to
    /// `nearest`.
    public static func composite(from components: [AirComponent]) -> AirQuality? {
        let ranked = components.filter { $0.icaCategory >= 1 }
        guard let driver = ranked.max(by: { a, b in
            a.icaCategory != b.icaCategory
                ? a.icaCategory < b.icaCategory
                : (a.distanceKm ?? .infinity) > (b.distanceKm ?? .infinity)   // ties: the nearer wins
        }) else { return nil }
        let measured = components.compactMap(\.measured).max() ?? Date()
        return AirQuality(category: driver.icaCategory, partial: false, pollutant: driver.pollutant,
                          station: driver.station ?? "", distanceKm: driver.distanceKm ?? 0,
                          measured: measured, components: components)
    }

    /// One station's latest ICA value per pollutant, via a single `sql1` POST over the station's UTC day.
    /// Empty — never throws — on any failure.
    static func stationReadings(_ s: Station,
                                session: URLSession = .shared) async -> [String: (value: Double, date: Date)] {
        let day = backendDay.string(from: s.measured)
        guard let body = requestBody(code: s.code, day: day) else { return [:] }
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [:] }
            return latestICAValues(data, day: day)
        } catch {
            return [:]
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

    /// One hourly row from `sql1`. `valor_medido` is the raw hourly concentration; `valor_media_movil` is
    /// the running mean the ICA is actually built from (8 h for O₃, 24 h for PM; null for NO₂/SO₂, which
    /// use the last hour). `dato_medido`/`dato_medido_mm` validate each; an unmeasured pollutant comes
    /// back all-null.
    private struct Reading: Decodable {
        let hora: Int
        let magnitud: String
        let valor_medido: Double?
        let dato_medido: Bool
        let valor_media_movil: Double?
        let dato_medido_mm: Bool?
    }

    /// The latest validated ICA value per pollutant: the running mean (`valor_media_movil`) when the
    /// backend supplies one — the value the índice is actually elaborated from — otherwise the last valid
    /// hourly `valor_medido` (NO₂/SO₂ carry no average). Unmeasured pollutants (all-null) are omitted, so
    /// there are never fabricated zeros. Keyed by magnitud, with the reading's UTC hour as a `Date`.
    static func latestICAValues(_ data: Data, day: String) -> [String: (value: Double, date: Date)] {
        guard let rows = try? JSONDecoder().decode([Reading].self, from: data) else { return [:] }
        var latest: [String: (hora: Int, value: Double)] = [:]
        for r in rows {
            let icaValue: Double?
            if let mm = r.valor_media_movil, r.dato_medido_mm == true { icaValue = mm }
            else if let v = r.valor_medido, r.dato_medido { icaValue = v }
            else { icaValue = nil }
            guard let value = icaValue else { continue }
            if let existing = latest[r.magnitud], existing.hora >= r.hora { continue }
            latest[r.magnitud] = (r.hora, value)
        }
        return latest.mapValues { (value: $0.value, date: hourDate(day: day, hour: $0.hora)) }
    }

    /// A `Date` for the reading's UTC hour on the query day (`day` is "yyyyMMdd", UTC).
    private static func hourDate(day: String, hour: Int) -> Date {
        (backendDay.date(from: day) ?? Date()).addingTimeInterval(Double(hour) * 3600)
    }

    /// The bare per-pollutant breakdown for one payload (no source), for the parser tests and any single-
    /// station use; `breakdown` is the app path. Uses today's UTC day only to stamp the (discarded) hour.
    static func parseComponents(_ data: Data) -> [AirComponent] {
        latestICAValues(data, day: backendDay.string(from: Date()))
            .map { AirComponent(pollutant: $0.key, value: $0.value.value) }
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
