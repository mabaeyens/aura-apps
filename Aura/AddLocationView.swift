import AuraKit
import SwiftUI

/// Searchable picker over the full bundled municipality table (`MunicipioDatabase`): accent- and
/// case-insensitive search across every Spanish municipality, with the capitals shown before a query.
struct AddLocationView: View {
    let onSelect: (Location) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Location] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        // No query yet: show the capitals as a starting point rather than all ~8100 municipalities.
        guard !trimmed.isEmpty else {
            return Location.seedCities.sorted { $0.nombre.localizedCaseInsensitiveCompare($1.nombre) == .orderedAscending }
        }
        // Accent- and case-insensitive search across the full municipality table, capped for a snappy list.
        let folded = trimmed.foldedForSearch
        return MunicipioDatabase.searchable.lazy.filter { $0.matches(folded) }.prefix(50).map(\.location)
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
