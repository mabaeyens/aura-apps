import UIKit

/// Swaps Aura's app icon to match the season. The four seasonal icons ship as *alternate* app icons
/// (declared via the `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` build setting); this picks the
/// one for today's date and asks iOS to switch to it when it isn't already showing.
///
/// Note: iOS shows a one-time system alert each time the icon actually changes — there is no public
/// API to suppress it. In practice that's at most four brief alerts a year, at the season turns.
enum AppIconManager {

    /// Astronomical seasons for the Northern Hemisphere (Spain): the icon turns at the equinoxes and
    /// solstices, using fixed approximate dates (they wander a day year to year) — spring Mar 20,
    /// summer Jun 21, autumn Sep 22, winter Dec 21. The `rawValue` is the alternate-icon asset name.
    enum Season: String, CaseIterable {
        case spring = "AuraSpring"
        case summer = "AuraSummer"
        case autumn = "AuraAutumn"
        case winter = "AuraWinter"

        static func current(for date: Date = Date(), calendar: Calendar = .current) -> Season {
            let c = calendar.dateComponents([.month, .day], from: date)
            let md = (c.month ?? 1) * 100 + (c.day ?? 1)   // e.g. Mar 20 → 320
            switch md {
            case 320...620:   return .spring
            case 621...921:   return .summer
            case 922...1220:  return .autumn
            default:          return .winter   // Dec 21 – Mar 19
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
