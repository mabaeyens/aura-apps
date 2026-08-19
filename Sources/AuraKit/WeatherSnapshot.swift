import Foundation

/// The small, self-contained bundle of weather a widget or complication needs to render one
/// location. The app (the fetch hub) writes these to the shared App Group cache; every widget
/// reads from that cache and never calls AEMET itself.
///
/// Phase 2 starts from what AuraKit already produces — the daily min/max and on-device sun times.
/// Later slices add the observed temperature, condition icon, hourly strip, UV and avisos.
public struct WeatherSnapshot: Codable, Sendable, Hashable {
    /// INE municipality code this snapshot describes (the widget's configured location).
    public let ine: String
    /// Display name of the municipality, e.g. "Madrid".
    public let localidad: String
    /// Province name, e.g. "Madrid".
    public let provincia: String
    /// Today's forecast low, °C.
    public let tempMin: Int?
    /// Today's forecast high, °C.
    public let tempMax: Int?
    /// Today's forecast peak relative humidity, %.
    public let humedadMax: Int?
    /// The forecast temperature for the current hour — the card's "now" hero. °C.
    public let currentTemp: Int?
    /// AEMET sky-state code for the current hour (e.g. "11", "13n"), for the condition icon.
    public let currentSky: String?
    /// AEMET's Spanish description of the current sky state (e.g. "Despejado").
    public let currentSkyText: String?
    /// Sunrise, computed on-device for the location.
    public let sunrise: Date?
    /// Sunset, computed on-device for the location.
    public let sunset: Date?
    /// The next few days' min/max, for the large widget's multi-day list.
    public let days: [DaySnapshot]
    /// The next few hours, for the hourly strip.
    public let hours: [HourSlot]
    /// When the app last refreshed this snapshot.
    public let updated: Date

    public init(ine: String, localidad: String, provincia: String,
                tempMin: Int?, tempMax: Int?, humedadMax: Int?,
                currentTemp: Int? = nil, currentSky: String? = nil, currentSkyText: String? = nil,
                sunrise: Date?, sunset: Date?,
                days: [DaySnapshot] = [], hours: [HourSlot] = [], updated: Date) {
        self.ine = ine
        self.localidad = localidad
        self.provincia = provincia
        self.tempMin = tempMin
        self.tempMax = tempMax
        self.humedadMax = humedadMax
        self.currentTemp = currentTemp
        self.currentSky = currentSky
        self.currentSkyText = currentSkyText
        self.sunrise = sunrise
        self.sunset = sunset
        self.days = days
        self.hours = hours
        self.updated = updated
    }
}

/// One hour of the hourly strip: the hour of day, its forecast temperature, sky code, and the
/// precipitation probability for the block it falls in.
public struct HourSlot: Codable, Sendable, Hashable, Identifiable {
    public let hour: Int          // 0–23, local
    public let temp: Int?
    public let sky: String?       // AEMET estadoCielo code
    public let precipProb: Int?   // %

    public var id: Int { hour }

    public init(hour: Int, temp: Int?, sky: String?, precipProb: Int?) {
        self.hour = hour
        self.temp = temp
        self.sky = sky
        self.precipProb = precipProb
    }
}

/// One day of the multi-day forecast, as a widget needs it.
public struct DaySnapshot: Codable, Sendable, Hashable, Identifiable {
    public let date: Date
    public let min: Int?
    public let max: Int?

    public var id: Date { date }

    public init(date: Date, min: Int?, max: Int?) {
        self.date = date
        self.min = min
        self.max = max
    }
}

public extension WeatherSnapshot {
    /// Build a snapshot for `location` from the daily forecast (min/max, multi-day list, sun times)
    /// and, when available, the hourly forecast (the "now" reading and the hourly strip). `timeZone`
    /// is the location's civil time, in which AEMET stamps its hours.
    static func make(location: Location,
                     daily: MunicipioForecast,
                     hourly: MunicipioHourly?,
                     timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid") ?? .current,
                     now: Date = Date()) -> WeatherSnapshot {
        let today = daily.prediccion.dia.first
        let sun = SolarTimes(date: now, latitude: location.latitude, longitude: location.longitude)
        let days = daily.prediccion.dia.prefix(5).compactMap { dia -> DaySnapshot? in
            guard let date = Self.parseDay(dia.fecha) else { return nil }
            return DaySnapshot(date: date, min: dia.temperatura?.minima, max: dia.temperatura?.maxima)
        }

        let hourly = hourly.map { Self.hourly($0, timeZone: timeZone, now: now) }

        return WeatherSnapshot(
            ine: location.ine,
            localidad: location.nombre,
            provincia: location.provincia,
            tempMin: today?.temperatura?.minima,
            tempMax: today?.temperatura?.maxima,
            humedadMax: today?.humedadRelativa?.maxima,
            currentTemp: hourly?.current?.temp,
            currentSky: hourly?.current?.sky,
            currentSkyText: hourly?.currentText,
            sunrise: sun.sunrise,
            sunset: sun.sunset,
            days: days,
            hours: hourly?.strip ?? [],
            updated: now
        )
    }

    /// Resolve the current hour and the next few hours from the hourly forecast.
    private static func hourly(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date)
        -> (current: HourSlot?, currentText: String?, strip: [HourSlot]) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let currentHour = cal.component(.hour, from: now)

        let dias = forecast.prediccion.dia
        let day0 = dias.first.map { slots(for: $0).filter { $0.hour >= currentHour } } ?? []
        let day1 = dias.count > 1 ? slots(for: dias[1]) : []
        let upcoming = day0 + day1

        let current = upcoming.first
        // Description for the current hour, from whichever day it came from.
        let text = dias.first.flatMap { skyText($0, hour: current?.hour) }
            ?? (dias.count > 1 ? skyText(dias[1], hour: current?.hour) : nil)

        return (current, text, Array(upcoming.prefix(6)))
    }

    /// Merge one day's parallel hourly arrays into ordered `HourSlot`s.
    private static func slots(for dia: MunicipioHourly.Dia) -> [HourSlot] {
        let temps = pairs(dia.temperatura)
        let skies = Dictionary(dia.estadoCielo.compactMap { s -> (Int, String)? in
            guard let h = Int(s.periodo) else { return nil }
            return (h, s.value)
        }, uniquingKeysWith: { a, _ in a })
        let blocks = dia.probPrecipitacion.compactMap { hv -> (start: Int, end: Int, value: Int)? in
            guard hv.periodo.count == 4,
                  let start = Int(hv.periodo.prefix(2)),
                  var end = Int(hv.periodo.suffix(2)),
                  let value = Int(hv.value) else { return nil }
            if end == 0 { end = 24 }
            return (start, end, value)
        }

        let hours = Set(temps.keys).union(skies.keys).sorted()
        return hours.map { hour in
            let prob = blocks.first { $0.start <= hour && hour < $0.end }?.value
            return HourSlot(hour: hour, temp: temps[hour], sky: skies[hour], precipProb: prob)
        }
    }

    private static func pairs(_ values: [MunicipioHourly.HourValue]) -> [Int: Int] {
        Dictionary(values.compactMap { hv -> (Int, Int)? in
            guard let h = Int(hv.periodo), let v = Int(hv.value) else { return nil }
            return (h, v)
        }, uniquingKeysWith: { a, _ in a })
    }

    private static func skyText(_ dia: MunicipioHourly.Dia, hour: Int?) -> String? {
        guard let hour else { return nil }
        return dia.estadoCielo.first { Int($0.periodo) == hour }?.descripcion
    }

    /// Parse AEMET's daily `fecha` ("yyyy-MM-dd" or "…'T'HH:mm:ss") at noon UTC, so day labels are
    /// stable regardless of the reader's time zone.
    private static func parseDay(_ raw: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let date = f.date(from: raw) {
                return Calendar(identifier: .gregorian).date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
            }
        }
        return nil
    }
}
