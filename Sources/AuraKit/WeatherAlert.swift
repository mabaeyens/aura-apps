import Foundation

/// One AEMET "aviso" (meteorological warning) for a warning zone, parsed from the CAP-XML product.
/// Warnings are matched to a location by province: the 6-digit zone code is
/// `[CCAA area][province INE][zone]`, so `provinceCode` is digits 3–4.
public struct WeatherAlert: Codable, Sendable, Hashable, Identifiable {
    /// AEMET's four warning levels, low → high.
    public enum Level: String, Codable, Sendable, CaseIterable {
        case verde, amarillo, naranja, rojo

        /// Higher is more severe; `verde` means no active warning.
        public var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    }

    public let level: Level
    /// AEMET's event title, e.g. "Aviso de temperaturas máximas de nivel naranja".
    public let event: String
    /// The phenomenon, e.g. "Temperatura máxima" (from the `parametro` field's middle component).
    public let phenomenon: String?
    /// 6-digit warning-zone code, e.g. "610401".
    public let zona: String
    /// Human-readable zone name, e.g. "Valle del Almanzora y Los Vélez".
    public let areaDesc: String?
    public let onset: Date?
    public let expires: Date?

    public var id: String { "\(zona)-\(event)" }

    /// Province INE code this warning's zone belongs to (digits 3–4 of the zone code).
    public var provinceCode: String {
        zona.count >= 4 ? String(zona.dropFirst(2).prefix(2)) : ""
    }

    /// A real, still-current warning (amber or above and not expired).
    public func isActive(at now: Date = Date()) -> Bool {
        level.rank >= Level.amarillo.rank && (expires.map { $0 >= now } ?? true)
    }

    /// A one or two word Spanish summary of the warning for a glance: "Calor", "Tormentas", "Nieve".
    /// AEMET's own phrasing ("Temperatura máxima", "Fenómenos costeros") is longer than the compact
    /// hint beside "MÁS" wants, so it is mapped to a plain word. Weather phenomena are checked before
    /// the temperature cases so a "rachas máximas de viento" reads as "Viento", not "Calor". Unknown
    /// phenomena fall back to their first word, or a generic "Aviso".
    public var shortLabel: String {
        let text = ((phenomenon ?? "") + " " + event).lowercased()
        func has(_ needles: String...) -> Bool { needles.contains { text.contains($0) } }
        switch true {
        case has("costero", "costera"):            return "Costa"
        case has("tormenta"):                      return "Tormentas"
        case has("nevada", "nieve"):               return "Nieve"
        case has("lluvia", "precipitaci", "aguacero"): return "Lluvia"
        case has("viento", "racha"):               return "Viento"
        case has("niebla"):                        return "Niebla"
        case has("polvo", "calima"):               return "Calima"
        case has("alud"):                          return "Aludes"
        case has("incend"):                        return "Incendios"
        case has("oleaje", "marejada", "temporal marítimo"): return "Oleaje"
        case has("máxim", "altas temp", "calor"):  return "Calor"
        case has("mínim", "bajas temp", "helada", "frío", "frio"): return "Frío"
        default:
            if let first = phenomenon?.split(separator: " ").first { return first.capitalized }
            return "Aviso"
        }
    }

    public init(level: Level, event: String, phenomenon: String?, zona: String,
                areaDesc: String?, onset: Date?, expires: Date?) {
        self.level = level
        self.event = event
        self.phenomenon = phenomenon
        self.zona = zona
        self.areaDesc = areaDesc
        self.onset = onset
        self.expires = expires
    }
}

public extension Array where Element == WeatherAlert {
    /// The most severe still-active warning for a province, if any — what a card surfaces.
    func topActive(forProvince code: String, at now: Date = Date()) -> WeatherAlert? {
        filter { $0.provinceCode == code && $0.isActive(at: now) }
            .max { $0.level.rank < $1.level.rank }
    }
}

// MARK: - Province → avisos area

/// Maps a province (INE code) to the AEMET avisos "area" code its CAP bulletin is published under.
/// Verified empirically against every published area; the middle two digits of each zone code are
/// the province INE, except for the island communities whose zones use island digits — so Balears
/// (07) and the two Canary provinces (35, 38) are mapped to their community's area explicitly.
public enum AvisoArea {
    public static func forProvincia(_ code: String) -> String? { map[code] }

    static let map: [String: String] = [
        "01": "75", "02": "68", "03": "77", "04": "61", "05": "67", "06": "70", "07": "64",
        "08": "69", "09": "67", "10": "70", "11": "61", "12": "77", "13": "68", "14": "61",
        "15": "71", "16": "68", "17": "69", "18": "61", "19": "68", "20": "75", "21": "61",
        "22": "62", "23": "61", "24": "67", "25": "69", "26": "76", "27": "71", "28": "72",
        "29": "61", "30": "73", "31": "74", "32": "71", "33": "63", "34": "67", "35": "65",
        "36": "71", "37": "67", "38": "65", "39": "66", "40": "67", "41": "61", "42": "67",
        "43": "69", "44": "62", "45": "68", "46": "77", "47": "67", "48": "75", "49": "67",
        "50": "62", "51": "78", "52": "79",
    ]
}

// MARK: - CAP parsing

/// Parses one AEMET CAP-XML alert file into `WeatherAlert`s (one per warning zone in the Spanish
/// `info` block). CAP uses a default namespace with no prefix, so element names are plain.
final class CAPParser: NSObject, XMLParserDelegate {
    static func parse(_ xml: Data) -> [WeatherAlert] {
        let delegate = CAPParser()
        let parser = XMLParser(data: xml)
        parser.delegate = delegate
        parser.parse()
        return delegate.alerts
    }

    private var alerts: [WeatherAlert] = []
    private var stack: [String] = []
    private var text = ""

    // Current <info> block state.
    private var language = ""
    private var event = ""
    private var nivel = ""
    private var parametro = ""
    private var onset = ""
    private var expires = ""
    private var areaDesc = ""
    private var zonesInInfo: [(zona: String, areaDesc: String)] = []
    // Current name/value pair inside a <parameter> or <geocode>.
    private var pairName = ""
    private var pairValue = ""

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        stack.append(element)
        text = ""
        switch element {
        case "info": resetInfo()
        case "parameter", "geocode": pairName = ""; pairValue = ""
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?,
                qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = stack.count >= 2 ? stack[stack.count - 2] : ""
        switch element {
        case "language": language = value
        case "event": event = value
        case "onset": onset = value
        case "expires": expires = value
        case "areaDesc": areaDesc = value
        case "valueName": pairName = value
        case "value": pairValue = value
        case "parameter":
            if pairName == "AEMET-Meteoalerta nivel" { nivel = pairValue }
            if pairName == "AEMET-Meteoalerta parametro" { parametro = pairValue }
        case "geocode":
            if pairName.lowercased().contains("zona"), !pairValue.isEmpty {
                zonesInInfo.append((pairValue, areaDesc))
            }
        case "info":
            emitInfo()
        default:
            break
        }
        _ = parent   // parent context is implicit via reset points; kept for clarity
        stack.removeLast()
    }

    private func resetInfo() {
        language = ""; event = ""; nivel = ""; parametro = ""
        onset = ""; expires = ""; areaDesc = ""; zonesInInfo = []
    }

    private func emitInfo() {
        guard language.lowercased().hasPrefix("es"),
              let level = WeatherAlert.Level(rawValue: nivel.lowercased()) else { return }
        let phenomenon = parametro.split(separator: ";").count >= 2
            ? String(parametro.split(separator: ";")[1]) : nil
        let onsetDate = isoFormatter.date(from: onset)
        let expiresDate = isoFormatter.date(from: expires)
        for zone in zonesInInfo {
            alerts.append(WeatherAlert(level: level, event: event, phenomenon: phenomenon,
                                       zona: zone.zona, areaDesc: zone.areaDesc,
                                       onset: onsetDate, expires: expiresDate))
        }
    }

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
