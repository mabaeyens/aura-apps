import AuraKit
import SwiftUI

/// Manage favorites: pick the active location, add from the bundled city list, use the
/// current GPS location, reorder, and delete.
struct LocationsView: View {
    @EnvironmentObject private var store: LocationStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        locationManager.resolveNearestCity { city in
                            if let city { store.add(city) }
                        }
                    } label: {
                        HStack {
                            Label(auraString("locations.useMyLocation"), systemImage: "location.fill")
                            if locationManager.isResolving {
                                Spacer(); ProgressView()
                            }
                        }
                    }
                    if locationManager.authorizationDenied {
                        Text(auraString("locations.permissionDenied"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(auraString("locations.favorites")) {
                    if store.favorites.isEmpty {
                        Text(auraString("locations.empty"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.favorites) { location in
                        Button {
                            store.selectedINE = location.ine
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(location.nombre)
                                    Text(location.provincia)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if location.ine == store.selectedINE {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                    .onDelete { store.remove(atOffsets: $0) }
                    .onMove { store.move(fromOffsets: $0, toOffset: $1) }
                }
            }
            .navigationTitle(auraString("locations.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(auraString("locations.add.title"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(auraString("common.done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddLocationView { store.add($0) }
            }
        }
    }
}
