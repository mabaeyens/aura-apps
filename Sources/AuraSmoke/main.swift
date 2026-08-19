import AuraKit
import Foundation

// Phase 0 smoke test: prove we can pull clean AEMET data end to end.
// Run:  AEMET_API_KEY=your-key swift run aura-smoke [ine]

let args = Array(CommandLine.arguments.dropFirst())

do {
    // The community narrative bulletin uses AEMET's website API — no key needed.
    //   swift run aura-smoke boletin [provincia]                  (default: 28 = Madrid → mad)
    if args.first == "boletin" {
        let provincia = args.dropFirst().first ?? "28"
        guard let comunidad = Comunidad.forProvincia(provincia) else {
            FileHandle.standardError.write(Data("Unknown province \(provincia)\n".utf8))
            exit(1)
        }
        let bulletin = try await AEMETBulletinClient().comunidad(comunidad)
        print("\(comunidad.nombre) — bulletin (elaborado \(bulletin.elaborado.map(String.init(describing:)) ?? "?")):\n")
        if let f = bulletin.fenomenoSignificativo { print("⚠︎ \(f)\n") }
        print(bulletin.texto)
        exit(0)
    }
} catch {
    FileHandle.standardError.write(Data("Smoke failed: \(error)\n".utf8))
    exit(1)
}

let key = ProcessInfo.processInfo.environment["AEMET_API_KEY"] ?? ""
guard !key.isEmpty else {
    FileHandle.standardError.write(Data("Set AEMET_API_KEY to run the smoke test.\n".utf8))
    exit(2)
}

let client = AEMETClient(apiKey: key)

do {
    if args.first == "ccaa" {
        // Verify the official CCAA forecast-text endpoint (the maintained product).
        //   AEMET_API_KEY=... swift run aura-smoke ccaa [code]          (default: mad)
        let ccaa = args.dropFirst().first ?? "mad"
        let bulletin = try await client.prediccionCCAAHoy(ccaa)
        print("CCAA \(ccaa) — official text bulletin:\n")
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
