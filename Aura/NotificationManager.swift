import AuraKit
import Foundation
import UserNotifications

/// The user's notification preference: none, avisos only, or avisos plus new forecasts. Chosen during
/// onboarding and changeable in Ajustes. Stored as a raw string in `UserDefaults.standard` so both the
/// SwiftUI `@AppStorage` bindings and the background-refresh path (which has no view) read one value.
enum NotificationLevel: String, CaseIterable, Identifiable {
    case off
    case avisos
    case avisosAndForecasts

    static let storageKey = "notificationLevel"

    var id: String { rawValue }

    /// Localized label for the pickers.
    var label: String {
        switch self {
        case .off: return auraString("notif.level.off")
        case .avisos: return auraString("notif.level.avisos")
        case .avisosAndForecasts: return auraString("notif.level.both")
        }
    }

    var wantsAvisos: Bool { self != .off }
    var wantsForecasts: Bool { self == .avisosAndForecasts }

    /// The stored preference, defaulting to `.off`.
    static var current: NotificationLevel {
        NotificationLevel(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .off
    }
}

/// Local notifications for new avisos and new forecast bulletins on the active (primary) location.
///
/// No push and no server. On every refresh, foreground or background, the app compares the freshly
/// built snapshot against the one already in the App Group cache and posts a local notification only
/// when something the user asked about actually changed. Avisos notify on naranja or rojo only;
/// forecasts notify when the community bulletin text changes. The old-versus-new comparison is also the
/// deduplication: a still-active aviso, or an unchanged bulletin, never re-notifies on the next refresh.
enum NotificationManager {
    private static var center: UNUserNotificationCenter { .current() }

    /// Retained delegate so foreground refreshes that find something new still show a banner.
    static let delegate = ForegroundPresenter()

    /// Wire the delegate and, for a returning user who already opted in, re-request authorization.
    /// Called once at launch. Safe to call repeatedly; iOS only ever prompts once.
    static func configure() {
        center.delegate = delegate
        requestAuthorizationIfNeeded()
    }

    /// Request notification authorization outright. Called when the user picks a non-off level.
    static func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Request only when the user has already opted into some notifications.
    static func requestAuthorizationIfNeeded() {
        guard NotificationLevel.current != .off else { return }
        requestAuthorization()
    }

    /// Compare the previously cached snapshot against the new one for the active location and post
    /// notifications per the user's setting. Call this for the primary location only.
    static func evaluatePrimary(old: WeatherSnapshot?, new: WeatherSnapshot) {
        let level = NotificationLevel.current
        guard level != .off else { return }

        if level.wantsAvisos {
            evaluateAviso(old: old?.alert, new: new.alert, localidad: new.localidad, ine: new.ine)
        }
        if level.wantsForecasts {
            evaluateForecast(old: old?.bulletin, new: new.bulletin,
                             phenomenon: new.bulletinPhenomenon, localidad: new.localidad, ine: new.ine)
        }
    }

    /// Naranja or rojo only, and only when it is genuinely new: a different warning, or an upgrade of the
    /// one already showing. (The event title embeds the level, so an upgrade changes the alert id too;
    /// the level check is a belt-and-braces second signal.)
    private static func evaluateAviso(old: WeatherAlert?, new: WeatherAlert?, localidad: String, ine: String) {
        guard let new, new.level.rank >= WeatherAlert.Level.naranja.rank else { return }
        let isNew = old.map { $0.id != new.id || $0.level != new.level } ?? true
        guard isNew else { return }

        post(id: "aviso-\(ine)",
             title: auraString("notif.aviso.title", new.level.rawValue, localidad),
             body: new.phenomenon ?? new.event)
    }

    /// Notify when the community bulletin text changes. Requires a previous, non-empty bulletin to
    /// compare against, so a location's first-ever forecast never fires one.
    private static func evaluateForecast(old: String?, new: String?, phenomenon: String?,
                                         localidad: String, ine: String) {
        guard let new, !new.isEmpty, let old, !old.isEmpty, old != new else { return }

        let body = phenomenon.map { auraString("notif.forecast.bodyWithPhenomenon", $0) }
            ?? auraString("notif.forecast.body")
        post(id: "prediccion-\(ine)", title: auraString("notif.forecast.title", localidad), body: body)
    }

    private static func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // Immediate delivery. A stable id per location coalesces repeats into a single entry.
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request)
    }
}

/// Shows a banner even when a refresh posts a notification while Aura is in the foreground.
final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
