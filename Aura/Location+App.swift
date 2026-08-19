import AuraKit
import Foundation

extension Location {
    /// The location's civil time zone. The Canary Islands (INE provinces 35 and 38) run one
    /// hour behind mainland Spain; everywhere else uses Europe/Madrid.
    var timeZone: TimeZone {
        switch provinciaCode {
        case "35", "38": return TimeZone(identifier: "Atlantic/Canary") ?? .current
        default: return TimeZone(identifier: "Europe/Madrid") ?? .current
        }
    }
}
