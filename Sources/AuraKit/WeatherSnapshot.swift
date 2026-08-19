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
    /// Sunrise, computed on-device for the location.
    public let sunrise: Date?
    /// Sunset, computed on-device for the location.
    public let sunset: Date?
    /// When the app last refreshed this snapshot.
    public let updated: Date

    public init(ine: String, localidad: String, provincia: String,
                tempMin: Int?, tempMax: Int?, humedadMax: Int?,
                sunrise: Date?, sunset: Date?, updated: Date) {
        self.ine = ine
        self.localidad = localidad
        self.provincia = provincia
        self.tempMin = tempMin
        self.tempMax = tempMax
        self.humedadMax = humedadMax
        self.sunrise = sunrise
        self.sunset = sunset
        self.updated = updated
    }
}

public extension WeatherSnapshot {
    /// Build a snapshot for `location` from a freshly fetched daily forecast, taking today's
    /// (first) day and computing sun times on-device.
    static func make(location: Location, forecast: MunicipioForecast, now: Date = Date()) -> WeatherSnapshot {
        let today = forecast.prediccion.dia.first
        let sun = SolarTimes(date: now, latitude: location.latitude, longitude: location.longitude)
        return WeatherSnapshot(
            ine: location.ine,
            localidad: location.nombre,
            provincia: location.provincia,
            tempMin: today?.temperatura?.minima,
            tempMax: today?.temperatura?.maxima,
            humedadMax: today?.humedadRelativa?.maxima,
            sunrise: sun.sunrise,
            sunset: sun.sunset,
            updated: now
        )
    }
}
