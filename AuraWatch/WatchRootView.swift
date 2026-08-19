import AuraKit
import SwiftUI

/// The Watch app's single screen: the most recently synced location. Data arrives from the iPhone
/// via `WatchSync` and lands in the Watch's own `SharedCache`; before the first sync it invites the
/// user to open Aura on the phone.
struct WatchRootView: View {
    @State private var snapshot: WeatherSnapshot? = SharedCache.read().first

    var body: some View {
        Group {
            if let snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot.localidad).font(.headline).lineLimit(1)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(snapshot.heroTemp.map { "\($0)°" } ?? "—")
                                .font(.system(size: 40, weight: .semibold, design: .rounded))
                            if let sky = snapshot.currentSkyText {
                                Text(sky).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }

                        if let alert = snapshot.alert {
                            Label(alert.phenomenon ?? "Aviso", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2).foregroundStyle(.orange)
                        }

                        Text("Máx \(fmt(snapshot.tempMax)) · Mín \(fmt(snapshot.tempMin))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView("Abre Aura en el iPhone", systemImage: "iphone")
            }
        }
        .onAppear { snapshot = SharedCache.read().first }
    }

    private func fmt(_ value: Int?) -> String { value.map { "\($0)°" } ?? "—" }
}
