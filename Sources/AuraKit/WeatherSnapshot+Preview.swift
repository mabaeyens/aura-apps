import Foundation

public extension WeatherSnapshot {
    /// Sample data for previews and the placeholder.
    static var preview: WeatherSnapshot {
        let cal = Calendar(identifier: .gregorian)
        let base = Date()
        let days = (0..<5).compactMap { offset -> DaySnapshot? in
            guard let date = cal.date(byAdding: .day, value: offset, to: base) else { return nil }
            return DaySnapshot(date: date, min: 17 + offset, max: 33 - offset)
        }
        let startHour = cal.component(.hour, from: base)
        let skies = ["11", "11", "12", "13", "13n", "14"]
        let hours = (0..<6).map { i in
            HourSlot(hour: (startHour + i) % 24, temp: 29 - i, sky: skies[i], precipProb: i >= 4 ? 15 : 0)
        }
        return WeatherSnapshot(
            ine: "28079", localidad: "Madrid", provincia: "Madrid",
            tempMin: 18, tempMax: 34, humedadMax: 55,
            currentTemp: 29, observedTemp: 30, observedStation: "Madrid Retiro",
            currentSky: "11", currentSkyText: "Despejado",
            windSpeed: 25, windDirection: .so,
            sunrise: cal.date(bySettingHour: 7, minute: 12, second: 0, of: base),
            sunset: cal.date(bySettingHour: 21, minute: 11, second: 0, of: base),
            days: days, hours: hours,
            alert: WeatherAlert(level: .naranja,
                                event: "Aviso de temperaturas máximas de nivel naranja",
                                phenomenon: "Temperatura máxima", zona: "280401",
                                areaDesc: "Metropolitana", onset: base,
                                expires: base.addingTimeInterval(3 * 3600)),
            updated: base
        )
    }
}
