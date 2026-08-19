import Foundation

/// The official narrative forecast for an area, as issued by an AEMET forecaster.
public struct ForecastBulletin: Sendable {
    /// When AEMET produced this bulletin.
    public let elaborado: Date?
    /// Start of the validity window.
    public let validezInicio: Date?
    /// End of the validity window.
    public let validezFin: Date?
    /// Highlighted significant phenomena (`fenom_sign`), if any.
    public let fenomenoSignificativo: String?
    /// The main narrative text (`txt_prediccion`).
    public let texto: String
}

/// Fetches community-level narrative forecasts from AEMET's website API
/// (`www.aemet.es/es/api-eltiempo`). No API key; this is the source that stays current for
/// every region, unlike the OpenData text products. Undocumented — see `Comunidad` for the
/// area-id mapping and how to re-harvest it if AEMET changes its scheme.
public struct AEMETBulletinClient: Sendable {

    public enum BulletinError: Error, Sendable {
        case http(Int)
        case parsing
    }

    private let session: URLSession
    private let base = "https://www.aemet.es/es/api-eltiempo/prediccion"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// The narrative bulletin for a community, for the day containing `date` (default: now),
    /// interpreted in Spanish civil time.
    public func comunidad(_ comunidad: Comunidad, on date: Date = Date()) async throws -> ForecastBulletin {
        let day = Self.dayFormatter.string(from: date)

        let path = "\(base)/\(day)/PB/\(comunidad.webZoom)/\(comunidad.webID)"
        guard let url = URL(string: path) else { throw BulletinError.parsing }

        let (data, response) = try await session.data(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw BulletinError.http(code) }

        let parser = BulletinXMLParser()
        guard let bulletin = parser.parse(data) else { throw BulletinError.parsing }
        return bulletin
    }

    /// `yyyy-MM-dd` in Spanish civil time, for the URL path.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

/// Parses the small `<root><elaborado/><validez_ini/>…<txt_prediccion/></root>` document.
/// The XML declares its own encoding (ISO-8859-15); `XMLParser` honours it from the raw bytes.
private final class BulletinXMLParser: NSObject, XMLParserDelegate {
    private var section: String?
    private var elaborado = "", validezIni = "", validezFin = "", fenom = "", texto = ""

    func parse(_ data: Data) -> ForecastBulletin? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return nil }

        let fenomTrimmed = fenom.trimmingCharacters(in: .whitespacesAndNewlines)
        return ForecastBulletin(
            elaborado: Self.date(elaborado),
            validezInicio: Self.date(validezIni),
            validezFin: Self.date(validezFin),
            fenomenoSignificativo: fenomTrimmed.isEmpty ? nil : fenomTrimmed,
            texto: texto.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        switch name {
        case "elaborado", "validez_ini", "validez_fin", "fenom_sign", "txt_prediccion":
            section = name
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch section {
        case "elaborado": elaborado += string
        case "validez_ini": validezIni += string
        case "validez_fin": validezFin += string
        case "fenom_sign": fenom += string
        case "txt_prediccion": texto += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        // Paragraph breaks inside the narrative sections.
        if name == "p" {
            if section == "fenom_sign" { fenom += "\n" }
            if section == "txt_prediccion" { texto += "\n" }
        }
        if name == section { section = nil }
    }

    private static func date(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.date(from: trimmed)
    }
}
