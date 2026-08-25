import XCTest
@testable import AuraKit

/// M1 coverage for the AEMET JSON decode contract. `AEMETClient`'s two-call plumbing (envelope +
/// `datos` follow, and the latin-1 -> utf-8 fallback) is private and network-bound, but the model
/// `Decodable` conformances are what break when AEMET renames or retypes a field, so these lock the
/// shapes.
///
/// Both tests decode REAL captured `datos` payloads (Madrid, INE 28079, from the daily and hourly
/// municipio endpoints), stored verbatim under Fixtures/ and transcoded to UTF-8 (the bytes the
/// decoder sees after the client's latin-1 fallback). That makes them genuine guards against an
/// upstream AEMET schema change, not just same-side regressions. Re-capture the same way to refresh.
final class AEMETDecodeTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
            "missing fixture \(name).json")
        return try Data(contentsOf: url)
    }

    // MARK: - Daily (MunicipioForecast)

    func testMunicipioForecastDecodesRealCapture() throws {
        // AEMET wraps the forecast in a one-element array; decoding the array form is the real path.
        let arr = try JSONDecoder().decode([MunicipioForecast].self,
                                            from: fixtureData("municipio_diaria_28079"))
        let f = try XCTUnwrap(arr.first)
        XCTAssertEqual(f.nombre, "Madrid")
        XCTAssertEqual(f.prediccion.dia.count, 7)

        let day0 = f.prediccion.dia[0]
        XCTAssertEqual(day0.temperatura?.maxima, 28)
        XCTAssertEqual(day0.temperatura?.minima, 18)
        // Daily `velocidad` is a plain Int (the hourly feed uses a String); real blocks range 0...15.
        XCTAssertEqual(day0.viento?.compactMap(\.velocidad).max(), 15)
        XCTAssertEqual(day0.viento?.first?.periodo, "00-24")
        // Daily `probPrecipitacion.value` is a plain Int; this capture is a dry day, so every block is 0.
        XCTAssertEqual(day0.probPrecipitacion?.compactMap(\.value).max(), 0)
        // The documented whole-day quirk: the "00-24" estadoCielo block carries an empty value.
        XCTAssertEqual(day0.estadoCielo?.first?.periodo, "00-24")
        XCTAssertEqual(day0.estadoCielo?.first?.value, "")

        // The late days (4...6) arrive with no `periodo` key, so the fields must stay optional to decode.
        let last = f.prediccion.dia[6]
        XCTAssertNil(last.estadoCielo?.first?.periodo)
        XCTAssertEqual(last.estadoCielo?.first?.value, "11")
        XCTAssertNil(last.viento?.first?.periodo)
        XCTAssertEqual(last.viento?.first?.direccion, "SO")
        XCTAssertEqual(last.viento?.first?.velocidad, 10)
    }

    // MARK: - Hourly (MunicipioHourly)

    func testMunicipioHourlyDecodesRealCapture() throws {
        let arr = try JSONDecoder().decode([MunicipioHourly].self,
                                            from: fixtureData("municipio_horaria_28079"))
        let h = try XCTUnwrap(arr.first)
        XCTAssertEqual(h.nombre, "Madrid")
        let day = try XCTUnwrap(h.prediccion.dia.first)
        XCTAssertNotNil(day.orto)
        XCTAssertNotNil(day.ocaso)

        // Hourly values are strings keyed by the single hour ("09"), unlike the daily feed's Ints.
        XCTAssertEqual(day.temperatura.count, 15)
        XCTAssertEqual(day.temperatura.first?.value, "19")
        XCTAssertEqual(day.temperatura.first?.periodo, "09")
        XCTAssertEqual(day.estadoCielo.first?.value, "17")
        XCTAssertEqual(day.estadoCielo.first?.descripcion, "Nubes altas")
        XCTAssertEqual(day.sensTermica?.first?.value, "19")
        XCTAssertEqual(day.precipitacion?.first?.value, "0")
        // probPrecipitacion arrives in coarser multi-hour blocks ("0814"), not per hour.
        XCTAssertEqual(day.probPrecipitacion.count, 3)
        XCTAssertEqual(day.probPrecipitacion.first?.periodo, "0814")

        // vientoAndRachaMax mixes two shapes in one array: wind entries carry `direccion`+`velocidad`
        // (single-element string arrays), gust entries only a scalar `value`. Both decode into WindValue.
        let wind = try XCTUnwrap(day.vientoAndRachaMax?.first { $0.direccion != nil })
        XCTAssertEqual(wind.direccion?.first, "SO")
        XCTAssertEqual(wind.velocidad?.first, "12")
        XCTAssertNil(wind.value)
        let gust = try XCTUnwrap(day.vientoAndRachaMax?.first { $0.value != nil && $0.direccion == nil })
        XCTAssertEqual(gust.value, "23")
    }

    /// The "Ip" (precipitación inapreciable) trace value isn't in the dry capture above, so guard that
    /// an hourly reading still decodes it as a plain string rather than choking on the non-numeric value.
    func testHourlyTraceValueDecodes() throws {
        let v = try decode(MunicipioHourly.HourValue.self, #"{"value":"Ip","periodo":"14"}"#)
        XCTAssertEqual(v.value, "Ip")
        XCTAssertEqual(v.periodo, "14")
    }

    // MARK: - Observation (StationObservation)

    func testObservacionTodasDecodesRealSlice() throws {
        // A 6-station slice of the national `observacion/convencional/todas` dump. The real feed carries
        // ~13 extra fields per row (prec, vmax, pres, ...) that the model must ignore, and `ta`/`hr` can
        // be null, which the model's optionals must tolerate.
        let stations = try JSONDecoder().decode([StationObservation].self,
                                                from: fixtureData("observacion_todas_slice"))
        XCTAssertEqual(stations.count, 6)

        let retiro = try XCTUnwrap(stations.first { $0.idema == "3195" })
        XCTAssertEqual(retiro.ubi, "MADRID RETIRO")
        XCTAssertEqual(retiro.ta, 23.6)
        XCTAssertEqual(retiro.lat ?? 0, 40.411389, accuracy: 0.0001)
        XCTAssertNotNil(retiro.timestamp)   // fint parses through the model's formatter

        // End-to-end on real data: nearest recent station to Madrid centre is Retiro. Pin `now` to the
        // slice's own reading time so the test stays deterministic and never ages out.
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        let now = try XCTUnwrap(fmt.date(from: "2026-08-25T11:00:00+0000"))
        let nearest = StationObservation.nearest(toLatitude: 40.4168, longitude: -3.7038,
                                                 in: stations, now: now, maxAge: 24 * 3600)
        XCTAssertEqual(nearest?.idema, "3195")
    }

    // MARK: - UV index (UVIForecast)

    func testUVIForecastDecodesRealCapture() throws {
        // Unlike the /prediccion products, uvi/{dia} is a bare object (not an array) with UPPERCASE
        // header keys and lowercase city keys; extra keys (FECHA_ELABORACION, FECHA_MOD, canarias) ignore.
        let forecast = try JSONDecoder().decode(UVIForecast.self, from: fixtureData("uvi_0"))
        XCTAssertEqual(forecast.fechaValidez, "2026-08-25T12:00:00")
        XCTAssertEqual(forecast.ciudad.count, 59)

        let madrid = try XCTUnwrap(forecast.ciudad.first { $0.id == "28079" })
        XCTAssertEqual(madrid.valor, "Madrid")
        XCTAssertEqual(madrid.uv, "8")   // the daily-max UV index arrives as a string integer

        // End-to-end: the INE lookup used on every refresh resolves the string "8" to an index of 8.
        XCTAssertEqual(UVIndex.pick(ine: "28079", in: forecast.ciudad)?.value, 8)
        XCTAssertNil(UVIndex.pick(ine: "00000", in: forecast.ciudad))
    }
}
