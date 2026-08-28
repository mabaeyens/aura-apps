import Foundation

// Chrome localization for AuraKit and the app targets that link it.
//
// AuraKit is a Swift package, so its `.strings` tables live in `Bundle.module`; a lookup that forgets
// the module bundle silently returns the key. These helpers are the single lookup path, so that can't
// happen by accident. They are `public` so the app, watch, widgets and complication targets resolve
// their own chrome through the same tables and the same process-language rule, with no per-target
// `.strings` wiring. Chrome only: weather data (AEMET/MITECO condition text, bulletins, aviso event
// text, place/station/pollutant names) and the on-device meteorological vocabulary (UV bands, ICA
// categories, Beaufort names, wind cardinals, moon phases, the forecast phrase) stay Spanish in every
// language and never pass through here.
//
// Language follows the OS (the per-app Settings language on device); Spanish is the base, English the
// override. Keys are semantic ("card.station.title"), never the Spanish text, so a miss is visible
// (the key shows) rather than silently rendering an untranslated literal.

/// AuraKit's own resource bundle (where the `.strings` tables live). Exposed so tests can load a
/// specific-language `.lproj` and assert both languages resolve, independently of the process language.
let auraKitBundle: Bundle = .module

/// The localized chrome string for `key`, from AuraKit's own tables. Returns the key itself if missing.
public func auraString(_ key: String) -> String {
    auraKitBundle.localizedString(forKey: key, value: key, table: "Localizable")
}

/// The localized chrome format string for `key`, filled with `args`. Placeholders are `%@` / `%1$@`
/// (string substitution only), so this never touches number or decimal formatting — those keep their
/// own explicit rules (e.g. the forced Spanish decimal comma).
public func auraString(_ key: String, _ args: CVarArg...) -> String {
    String(format: auraString(key), locale: Locale.current, arguments: args)
}
