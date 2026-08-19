import AuraKit
import Foundation

// Phase 0 smoke test: prove we can pull clean AEMET data end to end.
// Run:  AEMET_API_KEY=your-key swift run aura-smoke [ine]

let args = Array(CommandLine.arguments.dropFirst())

let key = ProcessInfo.processInfo.environment["AEMET_API_KEY"] ?? ""
guard !key.isEmpty else {
    FileHandle.standardError.write(Data("Set AEMET_API_KEY to run the smoke test.\n".utf8))
    exit(2)
}

let client = AEMETClient(apiKey: key)

do {
    if args.first == "boletin" {
        // The community narrative that covers today, resolved from OpenData (hoy-or-manana-archive).
        //   AEMET_API_KEY=... swift run aura-smoke boletin [provincia]   (default: 28 = Madrid → mad)
        let provincia = args.dropFirst().first ?? "28"
        guard let comunidad = Comunidad.forProvincia(provincia) else {
            FileHandle.standardError.write(Data("Unknown province \(provincia)\n".utf8))
            exit(1)
        }
        let bulletin = try await client.comunidadBulletin(comunidad)
        let issued = bulletin.elaborado.map(String.init(describing:)) ?? "?"
        print("\(comunidad.nombre) — bulletin (elaborado \(issued)):\n")
        if let f = bulletin.fenomenoSignificativo { print("⚠︎ \(f)\n") }
        print(bulletin.texto)
    } else if args.first == "ccaa" {
        // Verify the official CCAA forecast-text endpoint (the maintained product).
        //   AEMET_API_KEY=... swift run aura-smoke ccaa [code]          (default: mad)
        let ccaa = args.dropFirst().first ?? "mad"
        let bulletin = try await client.prediccionCCAAHoy(ccaa)
        print("CCAA \(ccaa) — official text bulletin:\n")
        print(bulletin)
    } else if args.first == "snapshot" {
        // Build the widget snapshot from live daily + hourly, and print what a widget would show.
        //   AEMET_API_KEY=... swift run aura-smoke snapshot [ine]      (default: 28079 = Madrid)
        let ine = args.dropFirst().first ?? "28079"
        let daily = try await client.municipioDiaria(ine)
        let hourly = try? await client.municipioHoraria(ine)
        let loc = Location(ine: ine, nombre: daily.nombre, provincia: daily.provincia,
                           latitude: 40.4, longitude: -3.7)
        let observed = try? await client.observacionTodas().nearest(to: loc)
        let s = WeatherSnapshot.make(location: loc, daily: daily, hourly: hourly, observed: observed)
        print("\(s.localidad): ahora \(s.heroTemp.map { "\($0)°" } ?? "—") \(s.currentSkyText ?? "?")")
        if let observed { print("  Observado: \(observed.temperature.map { "\($0)°" } ?? "—") en \(observed.stationName ?? "?") (\(observed.fint ?? "?"))") }
        print("  Máx \(s.tempMax.map(String.init) ?? "—") / Mín \(s.tempMin.map(String.init) ?? "—")  Humedad \(s.humedadMax.map { "\($0)%" } ?? "—")")
        print("  Horas: " + s.hours.map { "\($0.hour)h \($0.temp.map { "\($0)°" } ?? "—") [\($0.sky ?? "?")] \($0.precipProb.map { "\($0)%" } ?? "")" }.joined(separator: " · "))
        print("  Días: " + s.days.map { "\($0.min.map(String.init) ?? "—")/\($0.max.map(String.init) ?? "—")" }.joined(separator: " "))
    } else if args.first == "raw" {
        // Probe any normalized-text endpoint verbatim, e.g.
        //   AEMET_API_KEY=... swift run aura-smoke raw /prediccion/ccaa/manana/gal
        let path = args.dropFirst().first ?? "/prediccion/ccaa/hoy/mad"
        let bulletin = try await client.fetchText(path)
        print("GET \(path)\n")
        print(bulletin)
    } else if args.first == "texto" || args.first == "text" {
        // The (deprecated) per-province forecast-text endpoint.
        //   AEMET_API_KEY=... swift run aura-smoke texto [provincia]   (default: 28 = Madrid)
        let provincia = args.dropFirst().first ?? "28"
        let bulletin = try await client.prediccionProvinciaHoy(provincia)
        print("Province \(provincia) — official text bulletin:\n")
        print(bulletin)
    } else {
        // Numeric daily forecast (default).
        //   AEMET_API_KEY=... swift run aura-smoke [ine]              (default: 28079 = Madrid)
        let ine = args.first ?? "28079"
        let forecast = try await client.municipioDiaria(ine)
        print("Forecast for \(forecast.nombre) (\(forecast.provincia))")
        for dia in forecast.prediccion.dia.prefix(4) {
            let max = dia.temperatura?.maxima.map(String.init) ?? "-"
            let min = dia.temperatura?.minima.map(String.init) ?? "-"
            print("  \(dia.fecha): min \(min) / max \(max) ºC")
        }
    }
} catch {
    FileHandle.standardError.write(Data("Smoke failed: \(error)\n".utf8))
    exit(1)
}
