import AuraKit
import Foundation

// Phase 0 smoke test: prove we can pull clean AEMET data end to end.
// Run:  AEMET_API_KEY=your-key swift run aura-smoke [ine]

let key = ProcessInfo.processInfo.environment["AEMET_API_KEY"] ?? ""
guard !key.isEmpty else {
    FileHandle.standardError.write(Data("Set AEMET_API_KEY to run the smoke test.\n".utf8))
    exit(2)
}

let ine = CommandLine.arguments.dropFirst().first ?? "28079" // default: Madrid
let client = AEMETClient(apiKey: key)

do {
    let forecast = try await client.municipioDiaria(ine)
    print("Forecast for \(forecast.nombre) (\(forecast.provincia))")
    for dia in forecast.prediccion.dia.prefix(4) {
        let max = dia.temperatura?.maxima.map(String.init) ?? "-"
        let min = dia.temperatura?.minima.map(String.init) ?? "-"
        print("  \(dia.fecha): min \(min) / max \(max) ºC")
    }
} catch {
    FileHandle.standardError.write(Data("Smoke failed: \(error)\n".utf8))
    exit(1)
}
