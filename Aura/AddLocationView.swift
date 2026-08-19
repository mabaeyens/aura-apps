import AuraKit
import SwiftUI

/// Searchable picker over the bundled city list. Phase 1 ships provincial capitals and a few
/// major cities; the full municipality table (with in-app search) lands in a later phase.
struct AddLocationView: View {
    let onSelect: (Location) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Location] {
        let sorted = Location.seedCities.sorted { $0.nombre.localizedCaseInsensitiveCompare($1.nombre) == .orderedAscending }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return sorted }
        return sorted.filter {
            $0.nombre.localizedCaseInsensitiveContains(query) ||
            $0.provincia.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(results) { location in
                Button {
                    onSelect(location)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(location.nombre)
                        Text(location.provincia)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            }
            .searchable(text: $query, prompt: "Buscar municipio")
            .navigationTitle("Añadir ubicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
