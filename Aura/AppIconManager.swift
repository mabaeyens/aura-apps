import UIKit

/// Swaps Aura's app icon to match the season. The four seasonal icons ship as *alternate* app icons
/// (declared via the `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` build setting); this picks the
/// one for today's date and asks iOS to switch to it when it isn't already showing.
///
/// Note: iOS shows a one-time system alert each time the icon actually changes — there is no public
/// API to suppress it. In practice that's at most four brief alerts a year, at the season turns.
enum AppIconManager {

    /// Meteorological seasons for the Northern Hemisphere (Spain): whole months, so the icon turns on
    /// the 1st of March/June/September/December. The `rawValue` is the alternate-icon asset name.
    enum Season: String, CaseIterable {
        case spring = "AuraSpring"
        case summer = "AuraSummer"
        case autumn = "AuraAutumn"
        case winter = "AuraWinter"

        static func current(for date: Date = Date(), calendar: Calendar = .current) -> Season {
            switch calendar.component(.month, from: date) {
            case 3...5:  return .spring
            case 6...8:  return .summer
            case 9...11: return .autumn
            default:     return .winter   // 12, 1, 2
            }
        }
    }

    /// Switch to the seasonal icon for `now` if the device isn't already showing it. Safe to call on
    /// every foreground: it no-ops when the icon already matches (so no repeated alerts), when the
    /// device doesn't support alternate icons, or — harmlessly — before the seasonal icons are added
    /// to the bundle (the failed switch is caught and logged).
    static func updateForSeason(now: Date = Date()) {
        let app = UIApplication.shared
        guard app.supportsAlternateIcons else { return }
        let desired = Season.current(for: now).rawValue
        guard app.alternateIconName != desired else { return }
        app.setAlternateIconName(desired) { error in
            if let error {
                print("Aura: no se pudo cambiar el icono de temporada (\(desired)): \(error.localizedDescription)")
            }
        }
    }
}
