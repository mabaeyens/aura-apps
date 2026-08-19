import AppIntents
import AuraKit

// The widget's configuration: which saved location it shows. The choices come from the App Group
// list the app mirrors (`SharedLocations`), so the picker lists exactly the user's favourites.

/// One selectable saved location in the widget's configuration UI.
struct LocationEntity: AppEntity {
    let id: String            // INE code
    let nombre: String
    let provincia: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Ubicación" }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(nombre)", subtitle: "\(provincia)")
    }

    static var defaultQuery = LocationQuery()
}

/// Populates the location chooser from the App Group list the app keeps in sync.
struct LocationQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LocationEntity] {
        SharedLocations.read()
            .filter { identifiers.contains($0.ine) }
            .map(LocationEntity.init)
    }

    func suggestedEntities() async throws -> [LocationEntity] {
        SharedLocations.read().map(LocationEntity.init)
    }

    func defaultResult() async -> LocationEntity? {
        try? await suggestedEntities().first
    }
}

/// The widget's editable configuration: a single location parameter.
struct SelectLocationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Ubicación" }
    static var description: IntentDescription { IntentDescription("Elige qué ubicación muestra el widget.") }

    @Parameter(title: "Ubicación")
    var location: LocationEntity?
}

private extension LocationEntity {
    init(_ location: Location) {
        self.init(id: location.ine, nombre: location.nombre, provincia: location.provincia)
    }
}
