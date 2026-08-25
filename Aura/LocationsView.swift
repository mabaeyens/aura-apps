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
                            Label("Usar mi ubicación", systemImage: "location.fill")
                            if locationManager.isResolving {
                                Spacer(); ProgressView()
                            }
                        }
                    }
                    if locationManager.authorizationDenied {
                        Text("Permiso de ubicación denegado. Actívalo en Ajustes del sistema.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Favoritas") {
                    if store.favorites.isEmpty {
                        Text("Aún no has guardado ubicaciones. Usa «Usar mi ubicación» o el botón + para añadir una.")
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
            .navigationTitle("Ubicaciones")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Añadir ubicación")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddLocationView { store.add($0) }
            }
        }
    }
}
