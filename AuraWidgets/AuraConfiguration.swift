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

/// The widget's editable configuration: a single location parameter. Used by the Lock Screen glances,
/// which have no background art to choose.
struct SelectLocationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Ubicación" }
    static var description: IntentDescription { IntentDescription("Elige qué ubicación muestra el widget.") }

    @Parameter(title: "Ubicación")
    var location: LocationEntity?
}

/// The background scene the Home Screen widget draws behind the live sky — the two wide base families.
/// "Naturaleza" is the bare landscape set; "Ciudad" is the cityscape set.
enum SceneStyle: String, AppEnum {
    case naturaleza
    case ciudad

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Escena" }
    static var caseDisplayRepresentations: [SceneStyle: DisplayRepresentation] {
        [.naturaleza: "Naturaleza", .ciudad: "Ciudad"]
    }

    /// The AuraKit family this style maps to for base-image resolution.
    var family: HeroBackground.Family { self == .ciudad ? .cityscape : .landscape }
}

/// The Home Screen widget's configuration: a location **and** a background scene. Kept separate from
/// `SelectLocationIntent` so the Lock Screen glances don't show a scene picker they can't use.
struct SelectHomeIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Ubicación y escena" }
    static var description: IntentDescription {
        IntentDescription("Elige la ubicación y el estilo de fondo del widget.")
    }

    @Parameter(title: "Ubicación")
    var location: LocationEntity?

    @Parameter(title: "Escena", default: .naturaleza)
    var scene: SceneStyle

    // A configuration intent with more than one parameter needs an explicit summary for every
    // parameter to bind reliably: without it the scene picker rendered but its selection never
    // reached the timeline (the widget stayed on the default Naturaleza). Listing both parameters
    // here binds them both.
    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$location
            \.$scene
        }
    }
}

private extension LocationEntity {
    init(_ location: Location) {
        self.init(id: location.ine, nombre: location.nombre, provincia: location.provincia)
    }
}
