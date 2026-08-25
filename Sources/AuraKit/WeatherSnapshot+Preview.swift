import Foundation

public extension WeatherSnapshot {
    /// Sample data for previews and the placeholder.
    static var preview: WeatherSnapshot {
        let cal = Calendar(identifier: .gregorian)
        let base = Date()
        let days = (0..<7).compactMap { offset -> DaySnapshot? in
            guard let date = cal.date(byAdding: .day, value: offset, to: base) else { return nil }
            return DaySnapshot(date: date, min: 17 + offset, max: 33 - offset,
                               sky: ["12", "13", "11", "14", "13", "43", "12"][offset],
                               probPrecip: [0, 10, 0, 20, 15, 60, 5][offset])
        }
        let startHour = cal.component(.hour, from: base)
        let skies = ["11", "11", "12", "13", "13n", "14", "14n", "13n", "12n", "11n", "11n", "12n"]
        let hours = (0..<12).map { i in
            HourSlot(hour: (startHour + i) % 24, temp: 29 - i, sky: skies[i],
                     precipProb: [0, 0, 0, 0, 15, 15, 20, 20, 10, 0, 0, 5][i])
        }
        // A realistic summer UV bell for today (matches live CAMS/Madrid), anchored to local midnight so
        // `todaySlots` and `current(at:)` pick it up.
        let sod = cal.startOfDay(for: base)
        let uvCurve: [Double] = [0, 0, 0, 0, 0, 0, 0, 0.6, 1.5, 3, 5, 6,
                                 7, 8, 8.2, 7, 5.5, 4, 2.5, 1, 0.4, 0, 0, 0]
        let uvHourly = (0..<24).map { h in
            UVHourSlot(date: sod.addingTimeInterval(Double(h) * 3600),
                       uv: uvCurve[h], clearSky: min(uvCurve[h] + 0.3, 8.5))
        }
        return WeatherSnapshot(
            ine: "28079", localidad: "Madrid", provincia: "Madrid",
            tempMin: 18, tempMax: 34, humedadMax: 55,
            currentTemp: 29, observedTemp: 30, observedStation: "Madrid Retiro",
            observedStationDistanceKm: 3.2,
            observedMetrics: [.temperature, .wind, .humidity, .pressure, .precipitation],
            currentSky: "11", currentSkyText: "Despejado",
            currentHumidity: 42, currentPrecipProb: 15,
            windSpeed: 25, windDirection: .so, windGust: 47,
            airQuality: AirQuality(category: 2, partial: false, pollutant: "O3",
                                   station: "Retiro", distanceKm: 1.7, measured: base,
                                   components: [AirComponent(pollutant: "NO2", value: 27),
                                                AirComponent(pollutant: "O3", value: 60),
                                                AirComponent(pollutant: "PM2.5", value: 8),
                                                AirComponent(pollutant: "PM10", value: 12.5),
                                                AirComponent(pollutant: "SO2", value: 4)]),
            uvIndex: UVIndex(value: 8),
            uvHourly: uvHourly,
            sunrise: cal.date(bySettingHour: 7, minute: 12, second: 0, of: base),
            sunset: cal.date(bySettingHour: 21, minute: 11, second: 0, of: base),
            days: days, hours: hours,
            alert: WeatherAlert(level: .naranja,
                                event: "Aviso de temperaturas máximas de nivel naranja",
                                phenomenon: "Temperatura máxima", zona: "280401",
                                areaDesc: "Metropolitana", onset: base,
                                expires: base.addingTimeInterval(3 * 3600)),
            bulletin: "Cielos poco nubosos o despejados por la mañana con intervalos de nubes altas por la tarde y nubosidad de evolución. Probables chubascos en la Sierra por la tarde con posibilidad de tormenta. Temperaturas máximas en descenso generalizado, podría ser notable en zonas de la Sierra. Viento flojo del oeste y suroeste, pasando a noroeste en la Sierra durante la tarde.",
            bulletinPhenomenon: "Descenso notable de las máximas en zonas de la Sierra",
            updated: base
        )
    }

    /// A rainy variant of `preview` — a long condition phrase and rain-coded skies — for exercising the
    /// wet-weather look (the widget rain overlay, the medium card's two-line condition line).
    static var previewRain: WeatherSnapshot {
        let cal = Calendar(identifier: .gregorian)
        let base = Date()
        let days = (0..<7).compactMap { offset -> DaySnapshot? in
            guard let date = cal.date(byAdding: .day, value: offset, to: base) else { return nil }
            return DaySnapshot(date: date, min: 17 + offset, max: 27 - offset,
                               sky: ["24", "24", "25", "13", "13", "46", "12"][offset],
                               probPrecip: [75, 70, 60, 20, 15, 60, 5][offset])
        }
        let startHour = cal.component(.hour, from: base)
        let skies = ["24", "24", "25", "24", "24n", "25n", "24n", "13n", "12n", "11n", "11n", "12n"]
        let hours = (0..<12).map { i in
            HourSlot(hour: (startHour + i) % 24, temp: 22 - i / 3, sky: skies[i],
                     precipProb: [75, 70, 65, 60, 55, 50, 40, 30, 20, 10, 5, 5][i])
        }
        return WeatherSnapshot(
            ine: "28079", localidad: "Madrid", provincia: "Madrid",
            tempMin: 21, tempMax: 27, humedadMax: 80,
            currentTemp: 21, observedTemp: 21, observedStation: "Madrid Retiro",
            observedStationDistanceKm: 3.2,
            observedMetrics: [.temperature, .wind, .humidity],
            currentSky: "24", currentSkyText: "Muy nuboso con lluvia escasa",
            currentHumidity: 58, currentPrecipProb: 75,
            windSpeed: 19, windDirection: .so, windGust: 34,
            airQuality: nil,
            uvIndex: UVIndex(value: 3),
            uvHourly: nil,
            sunrise: cal.date(bySettingHour: 7, minute: 34, second: 0, of: base),
            sunset: cal.date(bySettingHour: 21, minute: 0, second: 0, of: base),
            days: days, hours: hours,
            alert: WeatherAlert(level: .amarillo,
                                event: "Aviso de lluvias de nivel amarillo",
                                phenomenon: "Lluvia", zona: "280401",
                                areaDesc: "Metropolitana", onset: base,
                                expires: base.addingTimeInterval(3 * 3600)),
            bulletin: "Cielos muy nubosos con lluvias débiles y ocasionales durante buena parte del día.",
            bulletinPhenomenon: "Lluvia persistente",
            updated: base
        )
    }
}
