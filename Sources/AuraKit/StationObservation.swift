import Foundation

/// One surface observation from AEMET's conventional network
/// (`/observacion/convencional/todas`), which returns many recent records per station across the
/// country. Aura uses it to show a real *observed* temperature near a location instead of the
/// forecast value for the current hour.
public struct StationObservation: Decodable, Sendable, Hashable {
    /// Station identifier (AEMET "idema").
    public let idema: String
    /// Human-readable station location, e.g. "MADRID RETIRO".
    public let ubi: String?
    /// Station latitude / longitude (decimal degrees). Optional so one malformed record can't abort
    /// the whole decode.
    public let lat: Double?
    public let lon: Double?
    /// Air temperature, °C.
    public let ta: Double?
    /// Relative humidity, %.
    public let hr: Double?
    /// Wind speed, m/s.
    public let vv: Double?
    /// Wind direction, degrees (0 = N, 90 = E).
    public let dv: Double?
    /// Barometric pressure, hPa.
    public let pres: Double?
    /// Precipitation over the station's accumulation period, mm.
    public let prec: Double?
    /// Reading timestamp, e.g. "2026-08-19T15:00:00+0000".
    public let fint: String?

    public init(idema: String, ubi: String?, lat: Double?, lon: Double?,
                ta: Double?, hr: Double?, fint: String?,
                vv: Double? = nil, dv: Double? = nil, pres: Double? = nil, prec: Double? = nil) {
        self.idema = idema
        self.ubi = ubi
        self.lat = lat
        self.lon = lon
        self.ta = ta
        self.hr = hr
        self.vv = vv
        self.dv = dv
        self.pres = pres
        self.prec = prec
        self.fint = fint
    }
}

/// Which surface metrics a station actually reports in a reading. Used to show, next to an observed
/// value, whether the resolving station covers everything or only some fields.
public struct ObservedMetrics: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let temperature   = ObservedMetrics(rawValue: 1 << 0)
    public static let wind          = ObservedMetrics(rawValue: 1 << 1)
    public static let humidity      = ObservedMetrics(rawValue: 1 << 2)
    public static let pressure      = ObservedMetrics(rawValue: 1 << 3)
    public static let precipitation = ObservedMetrics(rawValue: 1 << 4)
}

/// The actual surface values from the resolving station, for the observation card. Each field is
/// optional because a station may report only some metrics. Wind is stored in km/h (converted from
/// AEMET's m/s) so it matches every other wind reading in the app.
public struct ObservedReading: Codable, Sendable, Hashable {
    /// Air temperature, °C.
    public let temperature: Int?
    /// Relative humidity, %.
    public let humidity: Int?
    /// Wind speed, km/h.
    public let windKmh: Int?
    /// Wind direction, degrees (0 = N), when the station reports it.
    public let windDirection: WindDirection?
    /// Barometric pressure, hPa.
    public let pressure: Int?
    /// Precipitation over the station's accumulation period, mm.
    public let precipMm: Double?

    public init(temperature: Int?, humidity: Int?, windKmh: Int?,
                windDirection: WindDirection?, pressure: Int?, precipMm: Double?) {
        self.temperature = temperature
        self.humidity = humidity
        self.windKmh = windKmh
        self.windDirection = windDirection
        self.pressure = pressure
        self.precipMm = precipMm
    }
}

public extension StationObservation {
    /// Air temperature rounded to a whole degree, for display.
    var temperature: Int? { ta.map { Int($0.rounded()) } }

    /// The station's actual surface values, in display units, for the observation card.
    var reading: ObservedReading {
        ObservedReading(
            temperature: temperature,
            humidity: hr.map { Int($0.rounded()) },
            windKmh: vv.map { Int(($0 * 3.6).rounded()) },   // AEMET reports station wind in m/s
            windDirection: dv.map { WindDirection(degrees: $0) },
            pressure: pres.map { Int($0.rounded()) },
            precipMm: prec)
    }

    /// The reading time, parsed from `fint`. (Public via this extension — the app's refresh path reads the
    /// freshest record's measurement time to hold the hourly feed until the next reading is due.)
    var timestamp: Date? { fint.flatMap { Self.formatter.date(from: $0) } }

    /// Station name in title case ("Madrid Retiro"), from AEMET's all-caps `ubi`.
    var stationName: String? {
        ubi.map { $0.capitalized(with: Locale(identifier: "es_ES")) }
    }

    /// Great-circle distance from a location to this station, km — nil when the reading has no coordinates.
    func distanceKm(from location: Location) -> Double? {
        guard let lat, let lon else { return nil }
        return greatCircleKm(location.latitude, location.longitude, lat, lon)
    }

    /// Which surface metrics this reading actually carries — so the UI can show whether the
    /// resolving station reports everything or only some fields.
    var availableMetrics: ObservedMetrics {
        var metrics: ObservedMetrics = []
        if ta != nil { metrics.insert(.temperature) }
        if vv != nil { metrics.insert(.wind) }
        if hr != nil { metrics.insert(.humidity) }
        if pres != nil { metrics.insert(.pressure) }
        if prec != nil { metrics.insert(.precipitation) }
        return metrics
    }

    /// The freshest, nearest station reading to a coordinate — or nil when none is close and recent
    /// enough. `observations` is the raw list (many records per station): keep each station's
    /// latest reading with a temperature, drop readings older than `maxAge`, and return the nearest
    /// within `maxDistanceKm` (beyond which a reading isn't representative of the location).
    /// The tightened station radius (unified-freshness spec, shared with Android): beyond this a reading
    /// isn't representative of the location. Down from 35 km — altitude is the real culprit (a valley town
    /// vs a sierra station), but the record carries no elevation, so distance is the only lever. Locations
    /// with no station within this radius fall back to the forecast and hide the observation card.
    static let nearestStationKm: Double = 20

    static func nearest(toLatitude latitude: Double, longitude: Double,
                        in observations: [StationObservation],
                        now: Date = Date(),
                        maxAge: TimeInterval = 3 * 3600,
                        maxDistanceKm: Double = StationObservation.nearestStationKm) -> StationObservation? {
        var latest: [String: StationObservation] = [:]
        for obs in observations where obs.ta != nil && obs.lat != nil && obs.lon != nil {
            if let prev = latest[obs.idema],
               (prev.timestamp ?? .distantPast) >= (obs.timestamp ?? .distantPast) { continue }
            latest[obs.idema] = obs
        }

        return latest.values
            .filter { obs in
                guard let time = obs.timestamp else { return false }
                return abs(now.timeIntervalSince(time)) <= maxAge
            }
            .compactMap { obs -> (StationObservation, Double)? in
                guard let lat = obs.lat, let lon = obs.lon else { return nil }
                return (obs, greatCircleKm(latitude, longitude, lat, lon))
            }
            .filter { $0.1 <= maxDistanceKm }
            .min { $0.1 < $1.1 }?
            .0
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"   // "…+0000"
        return f
    }()
}

public extension Array where Element == StationObservation {
    /// The nearest recent station reading to a location, or nil when none is close and recent enough.
    func nearest(to location: Location) -> StationObservation? {
        StationObservation.nearest(toLatitude: location.latitude,
                                   longitude: location.longitude, in: self)
    }
}

/// Great-circle distance in kilometres (haversine).
private func greatCircleKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
    let r = 6371.0
    let p = Double.pi / 180
    let dLat = (lat2 - lat1) * p
    let dLon = (lon2 - lon1) * p
    let a = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1 * p) * cos(lat2 * p) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * r * asin(min(1, sqrt(a)))
}
