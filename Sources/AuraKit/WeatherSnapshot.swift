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
    /// Shown on the observation card; deliberately *not* folded into `heroTemp` (see there).
    public let observedTemp: Int?
    /// Name of the station `observedTemp` came from, e.g. "Madrid Retiro".
    public let observedStation: String?
    /// Great-circle distance from the location to that station, km.
    public let observedStationDistanceKm: Double?
    /// Which surface metrics that station actually reports, so the UI can show whether it covers
    /// everything or only some fields. Empty when no station resolved.
    public let observedMetrics: ObservedMetrics
    /// The station's actual surface values (temperature, humidity, wind, pressure, rain), in display
    /// units, for the observation card. Nil when no station resolved; individual fields nil where the
    /// station doesn't report them. Optional so an older cached snapshot decodes as nil.
    public let observedReading: ObservedReading?
    /// The observation's measurement time — AEMET's `fint`, stamped at the top of the hour in UTC. This is
    /// what lets the hero decide, at display time, whether the observation is more recent than the current
    /// forecast hour (the unified-freshness "most recent wins" rule). A *different clock* from `updated`
    /// (when the app fetched) and from the observation RSS publish time (~:31 past the hour); never compare
    /// them. Optional so an older cached snapshot decodes as nil — and a timestampless observation can't be
    /// proven current, so it never leads the hero until a refresh stamps one.
    public let observedAt: Date?
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
                observedStationDistanceKm: Double? = nil, observedMetrics: ObservedMetrics = [],
                observedReading: ObservedReading? = nil, observedAt: Date? = nil,
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
        self.observedStationDistanceKm = observedStationDistanceKm
        self.observedMetrics = observedMetrics
        self.observedReading = observedReading
        self.observedAt = observedAt
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
        // Guarantee sun times whenever coordinates are known. A snapshot built without orto/ocaso (some
        // data paths, cached or degraded loads) would otherwise leave the sun path unplaced, pinning both
        // the hero disc and the time-of-day label to a neutral noon. Compute them from the coordinates.
        if let sunrise, let sunset {
            self.sunrise = sunrise; self.sunset = sunset
        } else if let latitude, let longitude {
            let solar = SolarTimes(date: updated, latitude: latitude, longitude: longitude)
            self.sunrise = sunrise ?? solar.sunrise
            self.sunset = sunset ?? solar.sunset
        } else {
            self.sunrise = sunrise; self.sunset = sunset
        }
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
    /// The card's "now" hero temperature. °C, or nil only when there is genuinely neither a forecast nor a
    /// fresh measurement (the honest "—"). This is just `currentTemp` *after* `resolved(at:)` has re-derived
    /// it at display time, so the single source of truth for what the hero shows is `resolved(at:)`, not this
    /// accessor: the current-hour forecast, or a fresh station observation only when there is no forecast to
    /// show, then the frozen scalar. It is deliberately *not* today's high — falling back to `tempMax` once
    /// made a missing hourly feed read as a real "now" pinned to the day's peak. Render the value from a
    /// `resolved(at:)` snapshot; on a raw (unresolved) snapshot this is the frozen fetch-time scalar.
    var heroTemp: Int? { currentTemp }

    /// The snapshot re-anchored to `now` for **display** — the fix for the whole current-conditions family
    /// (temperature, sky, humidity, wind, precip…) freezing at fetch time and going stale at the next day
    /// change. A snapshot built and cached yesterday froze every `current*` scalar to yesterday's hour; served
    /// from cache today it would render those stale values (a blank `--`, yesterday's sky, yesterday's wind).
    ///
    /// This is the single display-time mechanism every surface uses: it re-derives each `current*` field from
    /// the timestamped hours strip re-anchored to the real `now` (`upcomingHours(now:)`, the exact mechanism the
    /// strip already uses), so the hero and the strip's first column are computed the same way and can never
    /// disagree. Each field falls back to its frozen scalar when the re-anchored strip doesn't carry it (a
    /// degraded/thin snapshot, or a snapshot cached before the strip carried that field), so this is **never
    /// worse** than the frozen value and better whenever the strip has the reading.
    ///
    /// The current **temperature** is forecast-only: the re-anchored current-hour forecast always leads, and
    /// because it is the same value the strip's first column shows, the hero and the strip can never disagree.
    /// The observation feed is a light national one that survives when the per-municipality hourly fetch is
    /// throttled, so *only* when there is no forecast temperature to show (an empty strip on a throttled or cold
    /// device) a fresh reading fills in rather than blanking, gated on the same `observationIsFresh` as the
    /// observation card — which is why an empty strip is no longer returned unchanged. The observation never
    /// overrides an available forecast, and "—" means there is genuinely neither a forecast nor a fresh reading.
    ///
    /// Call it once at each surface's display boundary (passing the live clock for the app and watch, the
    /// timeline entry date for widgets and complications) and render the returned snapshot; the rest of the
    /// view tree reads the ordinary `current*` properties and gets display-time values for free.
    /// Whether the observation is fresh enough to show on the observation card at `now`, per the
    /// unified-freshness display gate (concept 3, shared with Android as `observationIsFresh`). True only when
    /// the reading's measurement time (`observedAt`, AEMET's `fint`) is present, not in the future, and within
    /// `StationObservation.observationMaxAge` (3 h) of `now` — the very age `nearest` uses to *select* a
    /// station, so selection and display never drift. Past the gate the card hides rather than showing a stale
    /// number as live (the card analogue of the hero's most-recent fallback); a timestampless reading (an old
    /// cache from before `observedAt`) can't be proven fresh and never shows. Station presence is a separate
    /// concern the caller AND-s in, matching Android's `observedStation != null && observationIsFresh(now)`.
    func observationIsFresh(now: Date = Date()) -> Bool {
        guard let fint = observedAt, fint <= now else { return false }
        return now.timeIntervalSince(fint) <= StationObservation.observationMaxAge
    }

    /// The reading time to stamp on the observation card ("a las HH:MM") when the shown reading is **not** from
    /// the current clock hour, so a carried-forward value reads as last-known, not live. Nil when the reading
    /// is from the current hour (already "now", no stamp) or has no timestamp. Uses Europe/Madrid to match
    /// every other on-screen time. Shared with Android as `observationDisplayTime`; iOS returns the `Date` and
    /// formats it in the view (where iOS keeps formatting), Android returns the formatted string — same rule.
    func observationDisplayTime(now: Date = Date(),
                                timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid") ?? .current) -> Date? {
        guard let fint = observedAt else { return nil }
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        return cal.isDate(fint, equalTo: now, toGranularity: .hour) ? nil : fint
    }

    func resolved(at now: Date = Date(),
                  timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid") ?? .current) -> WeatherSnapshot {
        let strip = upcomingHours(now: now, timeZone: timeZone)
        func first<T>(_ key: (HourSlot) -> T?) -> T? {
            for slot in strip { if let v = key(slot) { return v } }
            return nil
        }
        // Hero temperature, forecast-only: the re-anchored current-hour forecast always leads (the same
        // value the strip's first column shows, so the two can never disagree). Only when there is no
        // forecast temperature at all — a throttled or cold device with an empty strip — does a fresh
        // station observation fill in rather than blanking, gated on the same `observationIsFresh` the
        // observation card uses, so the hero borrows a reading only while that reading is on screen. Then
        // the frozen scalar, then nil. The observation never overrides an available forecast.
        let heroTemp = first(\.temp)
            ?? (observationIsFresh(now: now) ? observedTemp : nil)
            ?? currentTemp
        return WeatherSnapshot(
            ine: ine, localidad: localidad, provincia: provincia,
            tempMin: tempMin, tempMax: tempMax, humedadMax: humedadMax,
            currentTemp: heroTemp,
            observedTemp: observedTemp, observedStation: observedStation,
            observedStationDistanceKm: observedStationDistanceKm, observedMetrics: observedMetrics,
            observedReading: observedReading, observedAt: observedAt,
            currentSky: first(\.sky) ?? currentSky,
            currentSkyText: first(\.skyText) ?? currentSkyText,
            currentHumidity: first(\.humidity) ?? currentHumidity,
            currentPrecipProb: first(\.precipProb) ?? currentPrecipProb,
            currentPrecipMm: first(\.precipMm) ?? currentPrecipMm,
            currentSnowMm: first(\.snowMm) ?? currentSnowMm,
            currentFeelsLike: first(\.feelsLike) ?? currentFeelsLike,
            currentStormProb: first(\.stormProb) ?? currentStormProb,
            windSpeed: first(\.windSpeed) ?? windSpeed,
            windDirection: first(\.windDirection) ?? windDirection,
            windGust: first(\.windGust) ?? windGust,
            airQuality: airQuality, uvIndex: uvIndex, uvHourly: uvHourly,
            sunrise: sunrise, sunset: sunset,
            latitude: latitude, longitude: longitude,
            days: days, hours: hours, alert: alert,
            bulletin: bulletin, bulletinPhenomenon: bulletinPhenomenon,
            updated: updated)
    }

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
    // The rest of the current-hour payload, so the re-anchored strip's slot carries *everything* the hero
    // needs and `resolved(at:)` can re-derive the whole `current*` family at display time — not just temp.
    // All optional so a snapshot cached before these fields decode them as nil (and fall back to the frozen
    // scalar). See `WeatherSnapshot.resolved(at:)`.
    public let skyText: String?       // AEMET estadoCielo description, e.g. "Despejado"
    public let humidity: Int?         // relative humidity, %
    public let precipMm: Double?      // rain amount, mm ("Ip" trace → 0)
    public let snowMm: Double?        // snow amount, mm
    public let feelsLike: Int?        // sensación térmica, °C
    public let stormProb: Int?        // storm probability, % (coarse block covering the hour)
    public let windDirection: WindDirection?  // whence the wind blows, or nil when calm/unknown

    public var id: Int { hour }

    public init(hour: Int, temp: Int?, sky: String?, precipProb: Int?, windSpeed: Int? = nil,
                windGust: Int? = nil, date: Date? = nil,
                skyText: String? = nil, humidity: Int? = nil, precipMm: Double? = nil,
                snowMm: Double? = nil, feelsLike: Int? = nil, stormProb: Int? = nil,
                windDirection: WindDirection? = nil) {
        self.hour = hour
        self.temp = temp
        self.sky = sky
        self.precipProb = precipProb
        self.windSpeed = windSpeed
        self.windGust = windGust
        self.date = date
        self.skyText = skyText
        self.humidity = humidity
        self.precipMm = precipMm
        self.snowMm = snowMm
        self.feelsLike = feelsLike
        self.stormProb = stormProb
        self.windDirection = windDirection
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
                     previousObserved: WeatherSnapshot? = nil,
                     alert: WeatherAlert? = nil,
                     airQuality: AirQuality? = nil,
                     uvIndex: UVIndex? = nil,
                     uvHourly: [UVHourSlot]? = nil,
                     bulletin: ForecastBulletin? = nil,
                     timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid") ?? .current,
                     now: Date = Date()) -> WeatherSnapshot {
        let today = daily.prediccion.dia.first
        let sun = SolarTimes(date: now, latitude: location.latitude, longitude: location.longitude)

        // Observation carry-forward: when this refresh skipped the hourly observation fetch (data not yet
        // due, or a transient error left `observed` nil), keep the last good station reading from the prior
        // snapshot rather than blanking the observed card. All-or-nothing per station so a fresh reading's
        // fields never mix with a stale one's. Carry-forward is bounded by the same age gate the card uses
        // (`observationIsFresh`, `StationObservation.observationMaxAge`): a previous reading is carried only
        // while it is within 3 h of `now`, and dropped past it, so a stale or out-of-radius reading can't be
        // pinned forever. The display layer re-checks the gate against the live `now`, so a reading that ages
        // out between refreshes still disappears; this bound stops the cache itself from hoarding it.
        let obsTemp: Int?
        let obsStation: String?
        let obsDistance: Double?
        let obsMetrics: ObservedMetrics
        let obsReading: ObservedReading?
        let obsAt: Date?
        if let observed {
            obsTemp = observed.temperature
            obsStation = observed.stationName
            obsDistance = observed.distanceKm(from: location)
            obsMetrics = observed.availableMetrics
            obsReading = observed.reading
            obsAt = observed.timestamp   // AEMET `fint`: the reading's measurement hour, for the hero's most-recent rule
        } else if let previousObserved, previousObserved.observationIsFresh(now: now) {
            obsTemp = previousObserved.observedTemp
            obsStation = previousObserved.observedStation
            obsDistance = previousObserved.observedStationDistanceKm
            obsMetrics = previousObserved.observedMetrics
            obsReading = previousObserved.observedReading
            obsAt = previousObserved.observedAt
        } else {
            obsTemp = nil
            obsStation = nil
            obsDistance = nil
            obsMetrics = []
            obsReading = nil
            obsAt = nil
        }

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

        // Hourly carry-forward: when the hourly feed is momentarily unavailable (the fetch failed or
        // returned nothing, leaving `hourly` nil), hold the last good current-hour reading from the prior
        // snapshot rather than blanking every `current*` field — which would silently drop the hero to
        // today's daily max and default the sky to a bare sun. Mirrors the observation carry-forward above;
        // gated strictly on a wholly-absent feed so a fresh current hour never mixes with a stale one.
        let carry: WeatherSnapshot? = hourly == nil ? previousObserved : nil
        let currentSky = resolved?.current?.sky ?? carry?.currentSky

        // Hero temperature: the first upcoming hour that actually carries a reading, not simply the first
        // upcoming slot. AEMET's rolling tail can list a sky for an hour with no matching temperature, so
        // taking that hour's (absent) temp blanked the hero to "—" even though the next hour has one.
        let heroTemp = resolved?.heroTemp

        // Hourly strip carry-forward. When the hourly fetch fails (`hourly` nil) or returns a degenerate feed
        // with no resolvable hours, `resolved?.strip` is empty — which would blank the next-hours card and
        // widget row. Hold the last good strip instead (the display layer re-anchors a stale strip to now),
        // mirroring the current* carry-forward. Only a genuine cold start with nothing cached leaves it empty.
        let stripNow = resolved?.strip ?? []
        let hoursStrip = stripNow.isEmpty ? (previousObserved?.hours ?? []) : stripNow

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
            // Carry the last good temperature forward not only when the feed is wholly absent (`carry`), but
            // also when it arrives present-but-temperature-less (a 200 whose current day has a sky yet no
            // `temperatura`): `previousObserved` still holds the prior reading, so the hero shows it rather
            // than blanking. nil only on a genuine cold start with nothing to fall back on.
            currentTemp: heroTemp ?? carry?.currentTemp ?? previousObserved?.currentTemp,
            observedTemp: obsTemp,
            observedStation: obsStation,
            observedStationDistanceKm: obsDistance,
            observedMetrics: obsMetrics,
            observedReading: obsReading,
            observedAt: obsAt,
            currentSky: currentSky,
            currentSkyText: resolved?.currentText ?? carry?.currentSkyText,
            currentHumidity: humidityNow ?? carry?.currentHumidity,
            currentPrecipProb: precipNow ?? carry?.currentPrecipProb,
            currentPrecipMm: precipMmNow ?? carry?.currentPrecipMm,
            currentSnowMm: snowMmNow ?? carry?.currentSnowMm,
            currentFeelsLike: feelsNow ?? carry?.currentFeelsLike,
            currentStormProb: stormNow ?? carry?.currentStormProb,
            windSpeed: wind?.speed ?? carry?.windSpeed,
            windDirection: wind?.direction ?? carry?.windDirection,
            windGust: wind?.gust ?? carry?.windGust,
            airQuality: airQuality,
            uvIndex: uvIndex,
            uvHourly: uvHourly,
            sunrise: sun.sunrise,
            sunset: sun.sunset,
            latitude: location.latitude,
            longitude: location.longitude,
            days: days,
            hours: hoursStrip,
            alert: alert,
            bulletin: bulletin?.texto,
            bulletinPhenomenon: bulletin?.fenomenoSignificativo,
            updated: now
        )
    }

    /// AEMET's hourly feed can briefly lead with a stale *past* day: for part of the morning its first
    /// `dia` is still yesterday, carrying only a handful of tail hours. Every current-hour reader below
    /// assumes `dia[0]` is today and filters by bare hour-of-day, so a yesterday-evening hour (e.g. 20:00)
    /// whose number is still ≥ the current morning hour survives the filter and is read as "now" — pinning
    /// the hero to a slot that can carry a sky but no temperature, which blanked it. Drop any day before the
    /// current calendar day so resolution always anchors on today; fall back to the raw list if that would
    /// leave nothing (a wholly stale feed), so behaviour is never worse than before.
    private static func futureDays(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> [MunicipioHourly.Dia] {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        let today = cal.startOfDay(for: now)
        // Keep only days on or after today, order-independently — a `filter`, not a `drop(while:)` that would
        // stop at the first kept day and let a malformed or out-of-order leading `dia` survive as the
        // "current" anchor. An unparseable date is dropped too, for the same reason. Fall back to the raw list
        // only if that leaves nothing (a wholly stale or wholly unparseable feed), so behaviour is never worse
        // than before.
        let kept = forecast.prediccion.dia.filter { dia in
            guard let midnight = dayMidnight(dia.fecha, timeZone: timeZone) else { return false }
            return midnight >= today
        }
        return kept.isEmpty ? forecast.prediccion.dia : kept
    }

    /// Resolve the current hour and the next few hours from the hourly forecast.
    private static func hourly(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date)
        -> (current: HourSlot?, currentText: String?, heroTemp: Int?, strip: [HourSlot]) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let currentHour = cal.component(.hour, from: now)

        let dias = futureDays(forecast, timeZone: timeZone, now: now)
        let day0 = dias.first.map { slots(for: $0, timeZone: timeZone).filter { $0.hour >= currentHour } } ?? []
        let day1 = dias.count > 1 ? slots(for: dias[1], timeZone: timeZone) : []
        let upcoming = day0 + day1

        let current = upcoming.first
        // The hero reads the first upcoming hour that actually carries a temperature — searched across the
        // whole upcoming window, not the 24-slot display strip, so a today made entirely of sky-only hours
        // still reaches tomorrow's first reading rather than blanking.
        let heroTemp = upcoming.first(where: { $0.temp != nil })?.temp
        // Description for the current hour, read from the *same* day the current slot came from. Once day 0's
        // hours are all past, `current` is day 1's first hour, so its text must come from day 1 too — reading
        // day 0's same-numbered hour would describe a different day and can disagree with the sky code (the
        // "Nubes altas" text over a clear background). nil here is honest; a wrong-day text is not.
        let currentDia = day0.isEmpty ? (dias.count > 1 ? dias[1] : nil) : dias.first
        let text = currentDia.flatMap { skyText($0, hour: current?.hour) }

        // Keep a full day ahead so the hourly strip has real data to scroll through (five show at once).
        return (current, text, heroTemp, Array(upcoming.prefix(24)))
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

        let dias = futureDays(forecast, timeZone: timeZone, now: now)
        if let day0 = dias.first, let w = wind(in: day0, from: currentHour) {
            return (w.0, w.1, gust(in: day0, from: currentHour))
        }
        if dias.count > 1, let w = wind(in: dias[1], from: 0) {
            return (w.0, w.1, gust(in: dias[1], from: 0))
        }
        return (nil, nil, nil)
    }

    /// Shared scaffold for the current-hour extractors: run `pick` over day 0 from the current hour, then
    /// day 1 from hour 0, returning the first non-nil result. Every `current*` reader differs only in `pick`.
    private static func currentValue<T>(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date,
                                        _ pick: (MunicipioHourly.Dia, Int) -> T?) -> T? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let currentHour = cal.component(.hour, from: now)
        let dias = futureDays(forecast, timeZone: timeZone, now: now)
        if let day0 = dias.first, let v = pick(day0, currentHour) { return v }
        if dias.count > 1, let v = pick(dias[1], 0) { return v }
        return nil
    }

    /// Pick from a single-hour array (`periodo` names one hour): the first reading at or after `from`, else
    /// the earliest available. `parse` converts the string value to the reading's type.
    private static func hourlyReading<V>(_ values: [MunicipioHourly.HourValue], from: Int,
                                         _ parse: (String) -> V?) -> V? {
        let readings = values.compactMap { hv -> (hour: Int, value: V)? in
            guard let hour = Int(hv.periodo), let value = parse(hv.value) else { return nil }
            return (hour, value)
        }.sorted { $0.hour < $1.hour }
        return (readings.first { $0.hour >= from } ?? readings.first)?.value
    }

    /// Parse a coarse-block array (`periodo` = "SSEE", start and end hour, e.g. "1218") into sorted
    /// (start, end, value) blocks; `end == 0` reads as 24. Shared by the block readers and `slots(for:)`.
    private static func blocks(_ values: [MunicipioHourly.HourValue]) -> [(start: Int, end: Int, value: Int)] {
        values.compactMap { hv -> (start: Int, end: Int, value: Int)? in
            guard hv.periodo.count == 4,
                  let start = Int(hv.periodo.prefix(2)),
                  var end = Int(hv.periodo.suffix(2)),
                  let value = Int(hv.value) else { return nil }
            if end == 0 { end = 24 }
            return (start, end, value)
        }.sorted { $0.start < $1.start }
    }

    /// Pick from a coarse-block array: the block covering `from`, else the next upcoming block, else the first.
    private static func blockReading(_ values: [MunicipioHourly.HourValue], from: Int) -> Int? {
        let bs = blocks(values)
        if let covering = bs.first(where: { $0.start <= from && from < $0.end }) { return covering.value }
        if let next = bs.first(where: { $0.start >= from }) { return next.value }
        return bs.first?.value
    }

    /// The relative humidity for the current hour (or the next available reading), %.
    private static func currentHumidity(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> Int? {
        currentValue(forecast, timeZone: timeZone, now: now) { dia, from in
            hourlyReading(dia.humedadRelativa, from: from) { Int($0) }
        }
    }

    /// The precipitation probability for the current hour, %, from the hourly feed's coarse blocks
    /// (periodo is 4 chars, "SSEE" — start and end hour, e.g. "1218"). Picks the block covering the
    /// current hour, else the next upcoming block.
    private static func currentPrecipProb(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> Int? {
        currentValue(forecast, timeZone: timeZone, now: now) { dia, from in
            blockReading(dia.probPrecipitacion, from: from)
        }
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
        currentValue(forecast, timeZone: timeZone, now: now) { dia, from in
            hourlyReading(dia.precipitacion ?? [], from: from) { precipAmount($0) }
        }
    }

    /// The snow amount for the current hour, mm, from the hourly feed.
    private static func currentSnowMm(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> Double? {
        currentValue(forecast, timeZone: timeZone, now: now) { dia, from in
            hourlyReading(dia.nieve ?? [], from: from) { precipAmount($0) }
        }
    }

    /// The feels-like temperature for the current hour, °C, from the hourly feed (single-hour `periodo`).
    private static func currentFeelsLike(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> Int? {
        currentValue(forecast, timeZone: timeZone, now: now) { dia, from in
            hourlyReading(dia.sensTermica ?? [], from: from) { Int($0) }
        }
    }

    /// The storm probability for the current hour, %, from the hourly feed's coarse blocks (same "SSEE"
    /// periodo format as `probPrecipitacion`).
    private static func currentStormProb(_ forecast: MunicipioHourly, timeZone: TimeZone, now: Date) -> Int? {
        currentValue(forecast, timeZone: timeZone, now: now) { dia, from in
            blockReading(dia.probTormenta ?? [], from: from)
        }
    }

    /// Merge one day's parallel hourly arrays into ordered `HourSlot`s, each stamped with the absolute
    /// instant it begins (in `timeZone`) so the strip can be re-anchored to the current hour at display.
    static func slots(for dia: MunicipioHourly.Dia, timeZone: TimeZone) -> [HourSlot] {
        let temps = pairs(dia.temperatura)
        let skies = Dictionary(dia.estadoCielo.compactMap { s -> (Int, String)? in
            guard let h = Int(s.periodo) else { return nil }
            return (h, s.value)
        }, uniquingKeysWith: { a, _ in a })
        // Sky description, humidity, feels-like, rain and snow amounts — each keyed by hour, so the slot
        // carries the same current-hour payload the fetch-time `current*` helpers read. Storm probability,
        // like precip, is a coarse block covering the hour.
        let skyTexts = Dictionary(dia.estadoCielo.compactMap { s -> (Int, String)? in
            guard let h = Int(s.periodo), let d = s.descripcion, !d.isEmpty else { return nil }
            return (h, d)
        }, uniquingKeysWith: { a, _ in a })
        let humidities = Dictionary(dia.humedadRelativa.compactMap { hv -> (Int, Int)? in
            guard let h = Int(hv.periodo), let v = Int(hv.value) else { return nil }
            return (h, v)
        }, uniquingKeysWith: { a, _ in a })
        let feels = Dictionary((dia.sensTermica ?? []).compactMap { hv -> (Int, Int)? in
            guard let h = Int(hv.periodo), let v = Int(hv.value) else { return nil }
            return (h, v)
        }, uniquingKeysWith: { a, _ in a })
        let rains = Dictionary((dia.precipitacion ?? []).compactMap { hv -> (Int, Double)? in
            guard let h = Int(hv.periodo), let v = precipAmount(hv.value) else { return nil }
            return (h, v)
        }, uniquingKeysWith: { a, _ in a })
        let snows = Dictionary((dia.nieve ?? []).compactMap { hv -> (Int, Double)? in
            guard let h = Int(hv.periodo), let v = precipAmount(hv.value) else { return nil }
            return (h, v)
        }, uniquingKeysWith: { a, _ in a })
        let dirs = Dictionary((dia.vientoAndRachaMax ?? []).compactMap { w -> (Int, WindDirection)? in
            guard let h = Int(w.periodo), let first = w.direccion?.first,
                  let d = WindDirection(aemet: first) else { return nil }
            return (h, d)
        }, uniquingKeysWith: { a, _ in a })
        let precipBlocks = blocks(dia.probPrecipitacion)
        let stormBlocks = blocks(dia.probTormenta ?? [])

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
            let prob = precipBlocks.first { $0.start <= hour && hour < $0.end }?.value
            let storm = stormBlocks.first { $0.start <= hour && hour < $0.end }?.value
            let date = dayStart.flatMap { cal.date(byAdding: .hour, value: hour, to: $0) }
            return HourSlot(hour: hour, temp: temps[hour], sky: skies[hour], precipProb: prob,
                            windSpeed: winds[hour], windGust: gusts[hour], date: date,
                            skyText: skyTexts[hour], humidity: humidities[hour], precipMm: rains[hour],
                            snowMm: snows[hour], feelsLike: feels[hour], stormProb: storm,
                            windDirection: dirs[hour])
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
