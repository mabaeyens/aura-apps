import Foundation

/// One clock-time formatter shared by every surface — app, widgets and Watch — so a single 24 h / 12 h
/// preference controls how times read everywhere. The preference lives in the App Group defaults, so the
/// widgets and the Watch complications format times the same way the app does, and it survives relaunch.
///
/// Only wall-clock times (sunrise, sunset, moonrise, the hourly strip, "actualizado a las…") flow through
/// here. Calendar dates ("28 ago") keep their own day/month formatting — the toggle is about the clock.
public enum AuraTime {
    /// Defaults key for the clock preference. `true` (the default) is 24-hour; `false` is 12-hour AM/PM.
    /// Spain runs on a 24-hour clock, so 24 h is the sensible default when the key is unset.
    public static let use24hKey = "AuraKit.use24hClock"

    /// The current clock preference, read from (and written to) the shared App Group defaults.
    public static var use24h: Bool {
        get { SharedCache.groupDefaults?.object(forKey: use24hKey) as? Bool ?? true }
        set { SharedCache.groupDefaults?.set(newValue, forKey: use24hKey) }
    }

    private static let formatter24: DateFormatter = {
        let f = DateFormatter(); f.locale = .autoupdatingCurrent; f.dateFormat = "HH:mm"; return f
    }()

    private static let formatter12: DateFormatter = {
        let f = DateFormatter(); f.locale = .autoupdatingCurrent
        f.dateFormat = "h:mm a"; f.amSymbol = "AM"; f.pmSymbol = "PM"; return f
    }()

    /// A wall-clock time: "18:34" in 24-hour, "6:34 PM" in 12-hour, per the current preference.
    public static func hhmm(_ date: Date) -> String {
        (use24h ? formatter24 : formatter12).string(from: date)
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter(); f.locale = .autoupdatingCurrent; f.dateFormat = "EEE"; return f
    }()

    /// A short capitalised weekday for the daily strips, in the UI language: "Lun"/"Mar" in Spanish,
    /// "Mon"/"Tue" in English. Clamped to three letters so a locale that appends a period ("lun.")
    /// doesn't leak it. Backed by one cached formatter — the daily cards call this once per row, so a
    /// fresh `DateFormatter` per call was a needless allocation on a hot render path.
    public static func shortWeekday(_ date: Date) -> String {
        String(weekdayFormatter.string(from: date).prefix(3)).capitalized
    }

    /// A bare hour for the hourly strip: "18h" in 24-hour, "6 PM" in 12-hour. Takes the 0…23 hour
    /// directly (the strip carries the hour as an integer), so no Date round-trip is needed.
    public static func hourLabel(hour: Int) -> String {
        if use24h { return "\(hour)h" }
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return "\(h12) \(hour < 12 ? "AM" : "PM")"
    }
}
