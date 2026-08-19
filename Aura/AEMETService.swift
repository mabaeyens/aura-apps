import AuraKit
import Foundation

/// Bridges the app to `AEMETClient`: builds a client from the stored key and turns
/// low-level client errors into Spanish, user-facing messages.
enum AEMETService {
    /// A client built from the Keychain key, or nil if no key has been entered yet.
    static func client() -> AEMETClient? {
        guard let key = AuraKeychain.apiKey(), !key.isEmpty else { return nil }
        return AEMETClient(apiKey: key)
    }

    /// Spanish message for any error surfaced while talking to AEMET.
    static func message(for error: Error) -> String {
        switch error {
        case AEMETClient.ClientError.missingAPIKey:
            return "Falta la clave de AEMET. Añádela en Ajustes."
        case AEMETClient.ClientError.rateLimited:
            return "AEMET ha limitado las peticiones. Inténtalo en un minuto."
        case AEMETClient.ClientError.http(let code):
            return "Error de red (HTTP \(code))."
        case AEMETClient.ClientError.aemetStatus(let code, let desc):
            return "AEMET devolvió \(code): \(desc)"
        case AEMETClient.ClientError.decoding:
            return "No se pudieron leer los datos de AEMET."
        case AEMETBulletinClient.BulletinError.http(let code):
            return "No se pudo obtener la predicción (HTTP \(code))."
        case AEMETBulletinClient.BulletinError.parsing:
            return "No se pudo leer la predicción de AEMET."
        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            return "Sin conexión. Se muestran los últimos datos disponibles."
        default:
            return "No se pudo obtener la información."
        }
    }
}
