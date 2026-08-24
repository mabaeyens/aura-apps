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
    /// Relative humidity for the current hour, %, from the hourly feed.
    public let currentHumidity: Int?
    /// Precipitation probability for the current hour, %, from the hourly feed's coarse blocks.
    public let currentPrecipProb: Int?
    /// Precipitation *amount* for the current hour, mm, from the hourly feed. 0 means dry; nil means the
    /// feed didn't carry it. A trace ("Ip") reads as 0.
    public let currentPrecipMm: Double?
    /// Snow *amount* for the current hour, mm, from the hourly feed. Same rules as `currentPrecipMm`.
    public let currentSnowMm: Double?
    /// Feels-like temperature for the current hour, °C, from the hourly feed.
    public let currentFeelsLike: Int?
    /// Storm probability for the current hour, %, from the hourly feed's coarse blocks.
    public let currentStormProb: Int?
    /// Current-hour wind speed, km/h.
    public let windSpeed: Int?
    /// Current-hour wind direction (whence it blows), or nil when calm/unknown.
    public let windDirection: WindDirection?
    /// Current-hour peak wind gust (racha máxima), km/h, from the hourly feed. Nil when AEMET
    /// omits it. Optional — an older cached snapshot decodes this as nil.
    public let windGust: Int?
    /// Sunrise, computed on-device for the location.
    public let airQuality: AirQuality?

    public let uvIndex: UVIndex?
    /// CAMS hourly UV forecast (via Open-Meteo), today + tomorrow, for a live "ahora" reading and a
    /// daytime curve — the hourly granularity AEMET's daily-max `uvIndex` lacks. Nil/empty when the
    /// feed is unavailable. See `OpenMeteoUV`.
    public let uvHourly: [UVHourSlot]?

    public let sunrise: Date?
    /// Sunset, computed on-device for the location.
    public let sunset: Date?
    /// The location's coordinates, so night-spanning cards can compute the *adjacent* day's sun times
    /// (tomorrow's orto, last night's ocaso) instead of reusing today's — today's sunset is 2–3 min off
    /// the neighbouring day's. Optional: snapshots cached before this field decode as nil and fall back to
    /// today's on-device times.
    public let latitude: Double?
    public let longitude: Double?
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
                currentHumidity: Int? = nil, currentPrecipProb: Int? = nil,
                currentPrecipMm: Double? = nil, currentSnowMm: Double? = nil,
                currentFeelsLike: Int? = nil, currentStormProb: Int? = nil,
                windSpeed: Int? = nil, windDirection: WindDirection? = nil,
                windGust: Int? = nil,
                airQuality: AirQuality? = nil,
                uvIndex: UVIndex? = nil,
                uvHourly: [UVHourSlot]? = nil,
                sunrise: Date?, sunset: Date?,
                latitude: Double? = nil, longitude: Double? = nil,
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
        self.currentHumidity = currentHumidity
        self.currentPrecipProb = currentPrecipProb
        self.currentPrecipMm = currentPrecipMm
        self.currentSnowMm = currentSnowMm
        self.currentFeelsLike = currentFeelsLike
        self.currentStormProb = currentStormProb
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.windGust = windGust
        self.airQuality = airQuality
        self.uvIndex = uvIndex
        self.uvHourly = uvHourly
        self.sunrise = sunrise
        self.sunset = sunset
        self.latitude = latitude
        self.longitude = longitude
        self.days = days
        self.hours = hours
        self.alert = alert
        self.bulletin = bulletin
        self.bulletinPhenomenon = bulletinPhenomenon
        self.updated = updated
    }
}

public extension WeatherSnapshot {
    /// The card's "now" hero temperature: the current-hour forecast, falling back to today's high only
    /// when the hourly feed is missing. °C. Deliberately *not* the observed-station reading — a warm
    /// nearby station read the day's max hours before the forecast said it would, so the gauge looked
    /// pinned to the high; tracking the hourly forecast keeps the hero consistent with the hours strip.
    var heroTemp: Int? { currentTemp ?? tempMax }

    /// Whether the hero is a real station observation. Now always false — kept for API compatibility.
    var heroIsObserved: Bool { false }

    /// The stored aviso, but only while it is still active at `now` (amarillo or worse, and not past its
    /// `expires`). Avisos are filtered for expiry when fetched, but a cached snapshot outlives its aviso's
    /// window: a fresh favourite is not refetched for an hour, so its snapshot keeps an aviso that has since
    /// expired. Every surface that shows the warning must gate on this rather than trust the raw `alert`,
    /// otherwise a widget pinned to a location the app is not currently refetching keeps flashing an aviso
    /// the app has already dropped. Returns nil when there is no aviso, or it has lapsed.
    func activeAlert(at now: Date = Date()) -> WeatherAlert? {
        alert.flatMap { $0.isActive(at: now) ? $0 : nil }
    }

    /// True when the snapshot carries current-hour data from the hourly feed — temperature, sky,
    /// humidity, precip chance, wind. When the hourly fetch comes back empty these all go nil together
    /// (the daily outlook, air quality and UV still populate), leaving a "thin" snapshot whose hero and
    /// wind rose would render blank. `WatchSync` uses this to refuse to overwrite a good cached snapshot
    /// with a thin one for the same location.
    var hasCurrentHourData: Bool {
        currentTemp != nil || currentSky != nil || currentHumidity != nil
            || currentPrecipProb != nil || windSpeed != nil || windDirection != nil
    }

    /// The hourly strip re-anchored to `now`: hours already past are dropped so the strip always begins
    /// at the *current* hour, even when the snapshot was built earlier (or served from cache hours or a
    /// day later). The current hour itself is kept as the first column.
    ///
    /// Each slot's absolute instant is its stamped `date`; for snapshots cached before slots carried one,
    /// it's reconstructed by walking the strip's wrapping hour sequence forward from `updated` (the build
    /// time), so the fix applies to an already-cached snapshot without waiting for a fresh fetch. If the
    /// snapshot is so old nothing remains ahead of `now`, the stored strip is returned unchanged.
    func upcomingHours(now: Date = Date(),
                       timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid") ?? .current) -> [HourSlot] {
        guard !hours.isEmpty else { return hours }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let hourStart = cal.dateInterval(of: .hour, for: now)?.start ?? now

        // Reconstruction anchor for nil-date slots: the build day's midnight, advanced by one day each
        // time the hour sequence wraps past midnight. The strip starts at/after the build hour, so the
        // first slot belongs to the build day.
        var anchorDay = cal.startOfDay(for: updated)
        var prevHour = -1
        let dated: [(slot: HourSlot, date: Date)] = hours.map { slot in
            if let d = slot.date { return (slot, d) }
            if slot.hour < prevHour {
                anchorDay = cal.date(byAdding: .day, value: 1, to: anchorDay) ?? anchorDay
            }
            prevHour = slot.hour
            let d = cal.date(bySettingHour: slot.hour, minute: 0, second: 0, of: anchorDay) ?? anchorDay
            return (slot, d)
        }
        let kept = dated.filter { $0.date >= hourStart }.map(\.slot)
        return kept.isEmpty ? hours : kept
    }

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

    /// Whether it's night at `date` for this location — before today's sunrise or after today's sunset.
    /// Lets a complication pick the moon icon at view time instead of trusting a possibly-stale AEMET
    /// day/night code. Falls back to the cached sky code's "n" suffix when sun times are unknown.
    func isNight(at date: Date = Date()) -> Bool {
        if let sunrise, let sunset {
            // Re-date the stored sun times onto `date`'s day: a day-old snapshot's absolute sunset is
            // "before now" at any hour, which otherwise reads as night at noon (see AuraSunPath.onSameDay).
            let sr = AuraSunPath.onSameDay(as: date, sunrise)
            let ss = AuraSunPath.onSameDay(as: date, sunset)
            return date < sr || date >= ss
        }
        return (currentSky ?? "").hasSuffix("n")
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
    public let windGust: Int?     // km/h, peak gust for the hour; nil when not reported
    /// The absolute instant this hour begins, so the strip can be re-anchored to the *real* current
    /// hour at display time — a snapshot built at 20:00 and served from cache at 09:55 the next day
    /// must still start at 09h, not 20h. Optional: snapshots cached before this field decode it as nil.
    public let date: Date?

    public var id: Int { hour }

    public init(hour: Int, temp: Int?, sky: String?, precipProb: Int?, windSpeed: Int? = nil,
                windGust: Int? = nil, date: Date? = nil) {
        self.hour = hour
        self.temp = temp
        self.sky = sky
        self.precipProb = precipProb
        self.windSpeed = windSpeed
        self.windGust = windGust
        self.date = date
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
    /// Representative precipitation probability for the day, % (max across AEMET's coarse blocks), for
    /// the daily list's rain-chance. Optional — an older cached snapshot decodes this as nil.
    public let probPrecip: Int?

    public var id: Date { date }

    public init(date: Date, min: Int?, max: Int?, humidityMax: Int? = nil,
                sky: String? = nil, windSpeed: Int? = nil, probPrecip: Int? = nil) {
        self.date = date
        self.min = min
        self.max = max
        self.humidityMax = humidityMax
        self.sky = sky
        self.windSpeed = windSpeed
        self.probPrecip = probPrecip
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
                     airQuality: AirQuality? = nil,
                     uvIndex: UVIndex? = nil,
                     uvHourly: [UVHourSlot]? = nil,
                     bulletin: ForecastBulletin? = nil,
                     timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid") ?? .current,
                     now: Date = Date()) -> WeatherSnapshot {
        let today = daily.prediccion.dia.first
        let sun = SolarTimes(date: now, latitude: location.latitude, longitude: location.longitude)

        // Resolve the hourly feed first, so today's daily row and the current humidity can follow the
        // actual current hour rather than a fixed whole-day block.
        let wind = hourly.map { Self.currentWind($0, timeZone: timeZone, now: now) }
        let humidityNow = hourly.flatMap { Self.currentHumidity($0, timeZone: timeZone, now: now) }
        let precipNow = hourly.flatMap { Self.currentPrecipProb($0, timeZone: timeZone, now: now) }
        let precipMmNow = hourly.flatMap { Self.currentPrecipMm($0, timeZone: timeZone, now: now) }
        let snowMmNow = hourly.flatMap { Self.currentSnowMm($0, timeZone: timeZone, now: now) }
        let feelsNow = hourly.flatMap { Self.currentFeelsLike($0, timeZone: timeZone, now: now) }
        let stormNow = hourly.flatMap { Self.currentStormProb($0, timeZone: timeZone, now: now) }
        let resolved = hourly.map { Self.hourly($0, timeZone: timeZone, now: now) }
        let currentSky = resolved?.current?.sky

        let days = daily.prediccion.dia.prefix(7).enumerated().compactMap { (idx, dia) -> DaySnapshot? in
            guard let date = Self.parseDay(dia.fecha) else { return nil }
            // Today (idx 0) follows the current hour: a clear morning shows a sun even when the
            // afternoon turns rainy, and the icon re-adapts as a fresh forecast arrives. Later days
            // keep their daytime-block summary.
            let sky = idx == 0 ? (currentSky ?? Self.dailySky(dia)) : Self.dailySky(dia)
            return DaySnapshot(date: date, min: dia.temperatura?.minima, max: dia.temperatura?.maxima,
                               humidityMax: dia.humedadRelativa?.maxima,
                               sky: sky, windSpeed: Self.dailyWind(dia),
                               probPrecip: Self.dailyPrecip(dia))
        }

        return WeatherSnapshot(
            ine: location.ine,
            localidad: location.nombre,
            provincia: location.provincia,
            tempMin: today?.temperatura?.minima,
            tempMax: today?.temperatura?.maxima,
            humedadMax: today?.humedadRelativa?.maxima,
            currentTemp: resolved?.current?.temp,
            observedTemp: observed?.temperature,
            observedStation: observed?.stationName,
            currentSky: resolved?.current?.sky,
            currentSkyText: resolved?.currentText,
            currentHumidity: humidityNow,
            currentPrecipProb: precipNow,
            currentPrecipMm: precipMmNow,
            currentSnowMm: snowMmNow,
            currentFeelsLike: feelsNow,
            currentStormProb: stormNow,
            windSpeed: wind?.speed ?? nil,
            windDirection: wind?.direction ?? nil,
            windGust: wind?.gust ?? nil,
            airQuality: airQuality,
            uvIndex: uvIndex,
            uvHourly: uvHourly,
            sunrise: sun.sunrise,
            sunset: sun.sunset,
            latitude: location.latitude,
            longitude: location.longitude,
            days: days,
            hours: resolved?.strip ?? [],
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
        let day0 = dias.first.map { slots(for: $0, timeZone: timeZone).filter { $0.hour >= currentHour } } ?? []
        let day1 = dias.count > 1 ? slots(for: dias[1], timeZone: timeZone) : []
        let upcoming = day0 + day1

        let current = upcoming.first
        // Description for the current hour, from whichever day it came from.
        let text = dias.first.flatMap { skyText($0, hour: current?.hour) }
            ?? (dias.count > 1 ? skyText(dias[1], hour: current?.hour) : nil)

        // Keep a full day ahead so the hourly strip has real data to scroll through (five show at once).
        return (current, text, Array(upcoming.prefix(24)))
    }

    /// The wind for the current hour (or the next available reading): speed km/h, direction, and peak gust.
    private static func currentWind(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date)
        -> (speed: Int?, direction: WindDirection?, gust: Int?) {
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

        // Gust entries carry a scalar `value` and no direccion/velocidad. Same at/after-`from` preference.
        func gust(in dia: MunicipioHourly.Dia, from: Int) -> Int? {
            let readings = (dia.vientoAndRachaMax ?? []).compactMap { w -> (hour: Int, gust: Int)? in
                guard let raw = w.value, w.velocidad == nil,
                      let hour = Int(w.periodo), let g = Int(raw) else { return nil }
                return (hour, g)
            }.sorted { $0.hour < $1.hour }
            return (readings.first { $0.hour >= from } ?? readings.first)?.gust
        }

        let dias = forecast.prediccion.dia
        if let day0 = dias.first, let w = wind(in: day0, from: currentHour) {
            return (w.0, w.1, gust(in: day0, from: currentHour))
        }
        if dias.count > 1, let w = wind(in: dias[1], from: 0) {
            return (w.0, w.1, gust(in: dias[1], from: 0))
        }
        return (nil, nil, nil)
    }

    /// The relative humidity for the current hour (or the next available reading), %.
    private static func currentHumidity(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> Int? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let currentHour = cal.component(.hour, from: now)

        func humidity(in dia: MunicipioHourly.Dia, from: Int) -> Int? {
            let readings = dia.humedadRelativa.compactMap { hv -> (hour: Int, value: Int)? in
                guard let hour = Int(hv.periodo), let value = Int(hv.value) else { return nil }
                return (hour, value)
            }.sorted { $0.hour < $1.hour }
            return (readings.first { $0.hour >= from } ?? readings.first)?.value
        }

        let dias = forecast.prediccion.dia
        if let day0 = dias.first, let h = humidity(in: day0, from: currentHour) { return h }
        if dias.count > 1, let h = humidity(in: dias[1], from: 0) { return h }
        return nil
    }

    /// The precipitation probability for the current hour, %, from the hourly feed's coarse blocks
    /// (periodo is 4 chars, "SSEE" — start and end hour, e.g. "1218"). Picks the block covering the
    /// current hour, else the next upcoming block.
    private static func currentPrecipProb(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> Int? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let currentHour = cal.component(.hour, from: now)

        func prob(in dia: MunicipioHourly.Dia, from: Int) -> Int? {
            let blocks = dia.probPrecipitacion.compactMap { hv -> (start: Int, end: Int, value: Int)? in
                guard hv.periodo.count == 4,
                      let start = Int(hv.periodo.prefix(2)),
                      var end = Int(hv.periodo.suffix(2)),
                      let value = Int(hv.value) else { return nil }
                if end == 0 { end = 24 }
                return (start, end, value)
            }.sorted { $0.start < $1.start }
            if let covering = blocks.first(where: { $0.start <= from && from < $0.end }) { return covering.value }
            if let next = blocks.first(where: { $0.start >= from }) { return next.value }
            return blocks.first?.value
        }

        let dias = forecast.prediccion.dia
        if let day0 = dias.first, let p = prob(in: day0, from: currentHour) { return p }
        if dias.count > 1, let p = prob(in: dias[1], from: 0) { return p }
        return nil
    }

    /// Parse an AEMET precipitation/snow amount string into mm. "Ip" (precipitación inapreciable) is a
    /// trace and reads as 0; empty or non-numeric returns nil (treated as "no data"). Accepts a decimal
    /// comma or dot.
    static func precipAmount(_ raw: String) -> Double? {
        let t = raw.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        if t.caseInsensitiveCompare("Ip") == .orderedSame { return 0 }
        return Double(t.replacingOccurrences(of: ",", with: "."))
    }

    /// The rain amount for the current hour, mm, from the hourly feed.
    private static func currentPrecipMm(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> Double? {
        currentMm(forecast, timeZone: timeZone, now: now) { $0.precipitacion }
    }

    /// The snow amount for the current hour, mm, from the hourly feed.
    private static func currentSnowMm(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> Double? {
        currentMm(forecast, timeZone: timeZone, now: now) { $0.nieve }
    }

    /// Current-hour amount in mm from one of the hourly amount arrays (single-hour `periodo`, same keying
    /// as humidity/temperature). Picks the current hour, else the next available.
    private static func currentMm(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date,
                                  _ array: (MunicipioHourly.Dia) -> [MunicipioHourly.HourValue]?) -> Double? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let currentHour = cal.component(.hour, from: now)

        func amount(in dia: MunicipioHourly.Dia, from: Int) -> Double? {
            let readings = (array(dia) ?? []).compactMap { hv -> (hour: Int, value: Double)? in
                guard let hour = Int(hv.periodo), let mm = precipAmount(hv.value) else { return nil }
                return (hour, mm)
            }.sorted { $0.hour < $1.hour }
            return (readings.first { $0.hour >= from } ?? readings.first)?.value
        }

        let dias = forecast.prediccion.dia
        if let day0 = dias.first, let mm = amount(in: day0, from: currentHour) { return mm }
        if dias.count > 1, let mm = amount(in: dias[1], from: 0) { return mm }
        return nil
    }

    /// The feels-like temperature for the current hour, °C, from the hourly feed (single-hour `periodo`).
    private static func currentFeelsLike(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> Int? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let currentHour = cal.component(.hour, from: now)

        func feels(in dia: MunicipioHourly.Dia, from: Int) -> Int? {
            let readings = (dia.sensTermica ?? []).compactMap { hv -> (hour: Int, value: Int)? in
                guard let hour = Int(hv.periodo), let value = Int(hv.value) else { return nil }
                return (hour, value)
            }.sorted { $0.hour < $1.hour }
            return (readings.first { $0.hour >= from } ?? readings.first)?.value
        }

        let dias = forecast.prediccion.dia
        if let day0 = dias.first, let f = feels(in: day0, from: currentHour) { return f }
        if dias.count > 1, let f = feels(in: dias[1], from: 0) { return f }
        return nil
    }

    /// The storm probability for the current hour, %, from the hourly feed's coarse blocks (same "SSEE"
    /// periodo format as `probPrecipitacion`).
    private static func currentStormProb(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> Int? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let currentHour = cal.component(.hour, from: now)

        func prob(in dia: MunicipioHourly.Dia, from: Int) -> Int? {
            let blocks = (dia.probTormenta ?? []).compactMap { hv -> (start: Int, end: Int, value: Int)? in
                guard hv.periodo.count == 4,
                      let start = Int(hv.periodo.prefix(2)),
                      var end = Int(hv.periodo.suffix(2)),
                      let value = Int(hv.value) else { return nil }
                if end == 0 { end = 24 }
                return (start, end, value)
            }.sorted { $0.start < $1.start }
            if let covering = blocks.first(where: { $0.start <= from && from < $0.end }) { return covering.value }
            if let next = blocks.first(where: { $0.start >= from }) { return next.value }
            return blocks.first?.value
        }

        let dias = forecast.prediccion.dia
        if let day0 = dias.first, let p = prob(in: day0, from: currentHour) { return p }
        if dias.count > 1, let p = prob(in: dias[1], from: 0) { return p }
        return nil
    }

    /// Merge one day's parallel hourly arrays into ordered `HourSlot`s, each stamped with the absolute
    /// instant it begins (in `timeZone`) so the strip can be re-anchored to the current hour at display.
    static func slots(for dia: MunicipioHourly.Dia, timeZone: TimeZone) -> [HourSlot] {
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

        // Per-hour peak gust, from the same array (gust entries carry a scalar `value`, no `velocidad`).
        let gusts = Dictionary((dia.vientoAndRachaMax ?? []).compactMap { w -> (Int, Int)? in
            guard let raw = w.value, w.velocidad == nil, let h = Int(w.periodo), let g = Int(raw) else { return nil }
            return (h, g)
        }, uniquingKeysWith: { a, _ in a })

        let dayStart = dayMidnight(dia.fecha, timeZone: timeZone)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let hours = Set(temps.keys).union(skies.keys).sorted()
        return hours.map { hour in
            let prob = blocks.first { $0.start <= hour && hour < $0.end }?.value
            let date = dayStart.flatMap { cal.date(byAdding: .hour, value: hour, to: $0) }
            return HourSlot(hour: hour, temp: temps[hour], sky: skies[hour], precipProb: prob,
                            windSpeed: winds[hour], windGust: gusts[hour], date: date)
        }
    }

    /// Midnight (local, in `timeZone`) of the calendar day AEMET's hourly `fecha` names, e.g.
    /// "2026-08-21T00:00:00" → that day's 00:00 in Madrid — the anchor for each hour's absolute instant.
    private static func dayMidnight(_ raw: String, timeZone: TimeZone) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let date = f.date(from: raw) {
                var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
                return cal.startOfDay(for: date)
            }
        }
        return nil
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

    /// The representative precipitation probability for a day, % — the max across AEMET's coarse blocks.
    /// The whole-day "00-24" block is unreliable (0 for day 0 even when the afternoon reads 55), and
    /// days 4–6 carry a single value with no `periodo`; taking the max is robust to both and answers the
    /// question a daily list poses — "any real chance of rain today?".
    private static func dailyPrecip(_ dia: MunicipioForecast.Dia) -> Int? {
        (dia.probPrecipitacion ?? []).compactMap { $0.value }.max()
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
