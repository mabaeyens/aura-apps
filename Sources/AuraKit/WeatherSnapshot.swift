import Foundation

/// The small, self-contained bundle of weather a widget or complication needs to render one
/// location. The app (the fetch hub) writes these to the shared App Group cache; every widget
/// reads from that cache and never calls AEMET itself.
///
/// It carries the daily min/max and on-device sun times, the current-hour forecast and hourly
/// strip, and — when a station is close and recent enough — a real observed temperature.
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
    /// The forecast temperature for the current hour. °C.
    public let currentTemp: Int?
    /// A real observed temperature from the nearest recent station, when one is close enough. °C.
    /// Preferred over `currentTemp` for the card's "now" hero.
    public let observedTemp: Int?
    /// Name of the station `observedTemp` came from, e.g. "Madrid Retiro".
    public let observedStation: String?
    /// AEMET sky-state code for the current hour (e.g. "11", "13n"), for the condition icon.
    public let currentSky: String?
    /// AEMET's Spanish description of the current sky state (e.g. "Despejado").
    public let currentSkyText: String?
    /// Current-hour wind speed, km/h.
    public let windSpeed: Int?
    /// Current-hour wind direction (whence it blows), or nil when calm/unknown.
    public let windDirection: WindDirection?
    /// Sunrise, computed on-device for the location.
    public let sunrise: Date?
    /// Sunset, computed on-device for the location.
    public let sunset: Date?
    /// The next few days' min/max, for the large widget's multi-day list.
    public let days: [DaySnapshot]
    /// The next few hours, for the hourly strip.
    public let hours: [HourSlot]
    /// The most severe active AEMET warning for this location's province, if any.
    public let alert: WeatherAlert?
    /// The community narrative bulletin covering today (AEMET's human-written text), when fetched.
    /// Only carried on the primary/selected location, since it's what the Watch shows.
    public let bulletin: String?
    /// The bulletin's significant-phenomenon headline, if any.
    public let bulletinPhenomenon: String?
    /// When the app last refreshed this snapshot.
    public let updated: Date

    public init(ine: String, localidad: String, provincia: String,
                tempMin: Int?, tempMax: Int?, humedadMax: Int?,
                currentTemp: Int? = nil, observedTemp: Int? = nil, observedStation: String? = nil,
                currentSky: String? = nil, currentSkyText: String? = nil,
                windSpeed: Int? = nil, windDirection: WindDirection? = nil,
                sunrise: Date?, sunset: Date?,
                days: [DaySnapshot] = [], hours: [HourSlot] = [],
                alert: WeatherAlert? = nil,
                bulletin: String? = nil, bulletinPhenomenon: String? = nil,
                updated: Date) {
        self.ine = ine
        self.localidad = localidad
        self.provincia = provincia
        self.tempMin = tempMin
        self.tempMax = tempMax
        self.humedadMax = humedadMax
        self.currentTemp = currentTemp
        self.observedTemp = observedTemp
        self.observedStation = observedStation
        self.currentSky = currentSky
        self.currentSkyText = currentSkyText
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.sunrise = sunrise
        self.sunset = sunset
        self.days = days
        self.hours = hours
        self.alert = alert
        self.bulletin = bulletin
        self.bulletinPhenomenon = bulletinPhenomenon
        self.updated = updated
    }
}

public extension WeatherSnapshot {
    /// The card's "now" hero temperature: the real observed reading when one is available, otherwise
    /// the current-hour forecast, otherwise today's high. °C.
    var heroTemp: Int? { observedTemp ?? currentTemp ?? tempMax }

    /// Whether the hero is a real station observation (so the UI can mark it as such).
    var heroIsObserved: Bool { observedTemp != nil }

    /// The next sun event to happen, for the sunrise/sunset complication: sunrise if it's still to
    /// come today, otherwise sunset if that's still to come, otherwise the next sunrise (sun times
    /// barely move day to day, so today's sunrise stands in for tomorrow's after dark).
    enum SunEvent: Sendable, Hashable { case sunrise(Date), sunset(Date) }

    func nextSunEvent(now: Date = Date()) -> SunEvent? {
        if let sr = sunrise, now < sr { return .sunrise(sr) }
        if let ss = sunset, now < ss { return .sunset(ss) }
        if let sr = sunrise { return .sunrise(sr) }
        return sunset.map { .sunset($0) }
    }
}

/// One hour of the hourly strip: the hour of day, its forecast temperature, sky code, and the
/// precipitation probability for the block it falls in.
public struct HourSlot: Codable, Sendable, Hashable, Identifiable {
    public let hour: Int          // 0–23, local
    public let temp: Int?
    public let sky: String?       // AEMET estadoCielo code
    public let precipProb: Int?   // %
    public let windSpeed: Int?    // km/h, for the hourly card's wind row

    public var id: Int { hour }

    public init(hour: Int, temp: Int?, sky: String?, precipProb: Int?, windSpeed: Int? = nil) {
        self.hour = hour
        self.temp = temp
        self.sky = sky
        self.precipProb = precipProb
        self.windSpeed = windSpeed
    }
}

/// One day of the multi-day forecast, as a widget or the "Hoy" list needs it.
public struct DaySnapshot: Codable, Sendable, Hashable, Identifiable {
    public let date: Date
    public let min: Int?
    public let max: Int?
    /// Peak relative humidity for the day, %. Lets "Hoy" render the daily list straight from the
    /// cached snapshot instead of re-fetching the forecast.
    public let humidityMax: Int?
    /// Representative sky code for the day (daytime block), for the days card's condition icon.
    public let sky: String?
    /// Representative wind speed for the day, km/h, for the days card's wind row.
    public let windSpeed: Int?

    public var id: Date { date }

    public init(date: Date, min: Int?, max: Int?, humidityMax: Int? = nil,
                sky: String? = nil, windSpeed: Int? = nil) {
        self.date = date
        self.min = min
        self.max = max
        self.humidityMax = humidityMax
        self.sky = sky
        self.windSpeed = windSpeed
    }
}

public extension WeatherSnapshot {
    /// Build a snapshot for `location` from the daily forecast (min/max, multi-day list, sun times)
    /// and, when available, the hourly forecast (the "now" reading and the hourly strip). `timeZone`
    /// is the location's civil time, in which AEMET stamps its hours.
    static func make(location: Location,
                     daily: MunicipioForecast,
                     hourly: MunicipioHourly?,
                     observed: StationObservation? = nil,
                     alert: WeatherAlert? = nil,
                     bulletin: ForecastBulletin? = nil,
                     timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid") ?? .current,
                     now: Date = Date()) -> WeatherSnapshot {
        let today = daily.prediccion.dia.first
        let sun = SolarTimes(date: now, latitude: location.latitude, longitude: location.longitude)
        let days = daily.prediccion.dia.prefix(5).compactMap { dia -> DaySnapshot? in
            guard let date = Self.parseDay(dia.fecha) else { return nil }
            return DaySnapshot(date: date, min: dia.temperatura?.minima, max: dia.temperatura?.maxima,
                               humidityMax: dia.humedadRelativa?.maxima,
                               sky: Self.dailySky(dia), windSpeed: Self.dailyWind(dia))
        }

        let wind = hourly.map { Self.currentWind($0, timeZone: timeZone, now: now) }
        let hourly = hourly.map { Self.hourly($0, timeZone: timeZone, now: now) }

        return WeatherSnapshot(
            ine: location.ine,
            localidad: location.nombre,
            provincia: location.provincia,
            tempMin: today?.temperatura?.minima,
            tempMax: today?.temperatura?.maxima,
            humedadMax: today?.humedadRelativa?.maxima,
            currentTemp: hourly?.current?.temp,
            observedTemp: observed?.temperature,
            observedStation: observed?.stationName,
            currentSky: hourly?.current?.sky,
            currentSkyText: hourly?.currentText,
            windSpeed: wind?.speed ?? nil,
            windDirection: wind?.direction ?? nil,
            sunrise: sun.sunrise,
            sunset: sun.sunset,
            days: days,
            hours: hourly?.strip ?? [],
            alert: alert,
            bulletin: bulletin?.texto,
            bulletinPhenomenon: bulletin?.fenomenoSignificativo,
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

    /// The wind for the current hour (or the next available reading), as speed km/h + direction.
    private static func currentWind(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date)
        -> (speed: Int?, direction: WindDirection?) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let currentHour = cal.component(.hour, from: now)

        // Wind entries (not gusts) at/after `from`, else the day's earliest, as (speed, direction).
        func wind(in dia: MunicipioHourly.Dia, from: Int) -> (Int?, WindDirection?)? {
            let readings = (dia.vientoAndRachaMax ?? []).compactMap { w -> (hour: Int, speed: Int?, dir: WindDirection?)? in
                guard let hour = Int(w.periodo),
                      let speed = w.velocidad?.first, let dir = w.direccion?.first else { return nil }
                return (hour, Int(speed), WindDirection(aemet: dir))
            }.sorted { $0.hour < $1.hour }
            guard let match = readings.first(where: { $0.hour >= from }) ?? readings.first else { return nil }
            return (match.speed, match.dir)
        }

        let dias = forecast.prediccion.dia
        if let day0 = dias.first, let w = wind(in: day0, from: currentHour) { return w }
        if dias.count > 1, let w = wind(in: dias[1], from: 0) { return w }
        return (nil, nil)
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

        // Per-hour wind speed, from the mixed wind/gust array (wind entries carry `velocidad`).
        let winds = Dictionary((dia.vientoAndRachaMax ?? []).compactMap { w -> (Int, Int)? in
            guard let h = Int(w.periodo), let first = w.velocidad?.first, let v = Int(first) else { return nil }
            return (h, v)
        }, uniquingKeysWith: { a, _ in a })

        let hours = Set(temps.keys).union(skies.keys).sorted()
        return hours.map { hour in
            let prob = blocks.first { $0.start <= hour && hour < $0.end }?.value
            return HourSlot(hour: hour, temp: temps[hour], sky: skies[hour], precipProb: prob,
                            windSpeed: winds[hour])
        }
    }

    /// The daytime sky code for a daily forecast block — prefers the whole-day/afternoon block so the
    /// days card shows a sun rather than a moon.
    private static func dailySky(_ dia: MunicipioForecast.Dia) -> String? {
        let blocks = dia.estadoCielo ?? []
        for periodo in ["00-24", "12-24", "12", "06-12", "00-12"] {
            if let value = blocks.first(where: { $0.periodo == periodo })?.value, !value.isEmpty {
                return value
            }
        }
        return blocks.first(where: { !$0.value.isEmpty })?.value
    }

    /// The representative wind speed for a daily forecast block, km/h — same block preference as the sky.
    private static func dailyWind(_ dia: MunicipioForecast.Dia) -> Int? {
        let blocks = dia.viento ?? []
        for periodo in ["00-24", "12-24", "12", "06-12", "00-12"] {
            if let speed = blocks.first(where: { $0.periodo == periodo })?.velocidad { return speed }
        }
        return blocks.compactMap { $0.velocidad }.max()
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
