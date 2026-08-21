import Foundation

/// A per-location forest-fire-danger reading: the Fire Weather Index (FWI) for the point, from the EU's
/// EFFIS / GWIS service. AEMET's own fire risk is map-only (a rendered, un-georeferenced image with no
/// per-coordinate value), so the actual "how flammable is it right here" number comes from JRC's GWIS
/// GeoServer instead — the same ECMWF-driven FWI grid EFFIS publishes its maps from.
///
/// The FWI is a unitless index (Canadian FWI System); we bucket the float into the classic EFFIS 6-level
/// danger scale ourselves rather than trusting the service's own class integer, so the names and colours
/// stay under our control. Source: EFFIS / GWIS — Copernicus EMS, © European Union (attribution required).
public struct FireRisk: Codable, Sendable, Hashable {
    /// The Fire Weather Index for the point (unitless; higher = more dangerous). ~0 in wet winter, well
    /// above 50 in a peak-summer heatwave.
    public let fwi: Double
    /// The day the value is valid for (the query date; GWIS is a daily product).
    public let measured: Date

    public init(fwi: Double, measured: Date) {
        self.fwi = fwi
        self.measured = measured
    }

    /// The classic EFFIS danger class, 1…6, bucketed from `fwi`. The 3/4/5 breakpoints are confirmed
    /// against live GWIS responses; the 1↔2 boundary (5.2) follows the published classic scale.
    public var dangerClass: Int {
        switch fwi {
        case ..<5.2:  return 1
        case ..<11.2: return 2
        case ..<21.3: return 3
        case ..<38.0: return 4
        case ..<50.0: return 5
        default:      return 6
        }
    }

    /// Spanish danger-class name (the six-level EFFIS scale).
    public var categoryName: String {
        switch dangerClass {
        case 1:  return "Muy bajo"
        case 2:  return "Bajo"
        case 3:  return "Moderado"
        case 4:  return "Alto"
        case 5:  return "Muy alto"
        default: return "Extremo"
        }
    }
}

/// Queries the JRC GWIS GeoServer for the Fire Weather Index at a single coordinate.
///
/// The mechanism is a WMS 1.3.0 `GetFeatureInfo` against the `ecmwf.query` layer with
/// `INFO_FORMAT=text/html` — the only format that carries the values. It's fully anonymous (no key, no
/// registration; `<Fees>none</Fees>`). GWIS serves a global ~8 km ECMWF grid covering the peninsula and
/// the Canaries, updated daily with a rolling window (recent archive + ~9-day forecast). Requests for a
/// date outside that window (or a sea pixel) return HTML with no FWI row, which we surface as nil so the
/// card is simply dropped rather than showing a stale or empty value.
public enum EFFISFireRisk {
    private static let base = "https://ies-ows.jrc.ec.europa.eu/gwis"

    /// The FWI at a point for `date` (default today), or nil if the service is unreachable, the pixel
    /// has no data, or the response can't be parsed. Never throws — a fire-risk miss must not block the
    /// forecast refresh.
    public static func fireRisk(latitude lat: Double, longitude lon: Double,
                                date: Date = Date(), session: URLSession = .shared) async -> FireRisk? {
        guard let url = requestURL(latitude: lat, longitude: lon, date: date) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8   // a shared public service; don't let a slow FWI stall the refresh
        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let html = String(decoding: data, as: UTF8.self)
            guard let fwi = parseFWI(html) else { return nil }
            return FireRisk(fwi: fwi, measured: date)
        } catch {
            return nil
        }
    }

    /// Build the GetFeatureInfo URL: a small bbox centred on the point (WMS 1.3.0 + EPSG:4326 → axis
    /// order is lat,lon), a 101×101 image, and the centre pixel (I=50, J=50) sampling the coordinate.
    static func requestURL(latitude lat: Double, longitude lon: Double, date: Date) -> URL? {
        let d = 0.05
        let bbox = "\(lat - d),\(lon - d),\(lat + d),\(lon + d)"   // miny(lat),minx(lon),maxy(lat),maxx(lon)
        var comps = URLComponents(string: base)
        comps?.queryItems = [
            URLQueryItem(name: "SERVICE", value: "WMS"),
            URLQueryItem(name: "VERSION", value: "1.3.0"),
            URLQueryItem(name: "REQUEST", value: "GetFeatureInfo"),
            URLQueryItem(name: "LAYERS", value: "ecmwf.query"),
            URLQueryItem(name: "QUERY_LAYERS", value: "ecmwf.query"),
            URLQueryItem(name: "STYLES", value: ""),               // required, may be empty
            URLQueryItem(name: "CRS", value: "EPSG:4326"),
            URLQueryItem(name: "BBOX", value: bbox),
            URLQueryItem(name: "WIDTH", value: "101"),
            URLQueryItem(name: "HEIGHT", value: "101"),
            URLQueryItem(name: "I", value: "50"),
            URLQueryItem(name: "J", value: "50"),
            URLQueryItem(name: "FEATURE_COUNT", value: "1"),
            URLQueryItem(name: "INFO_FORMAT", value: "text/html"),
            URLQueryItem(name: "TIME", value: dateFormatter.string(from: date)),
        ]
        return comps?.url
    }

    /// Pull the FWI float from the GetFeatureInfo HTML table. The row is
    /// `<td>Fire Weather Index (FWI)</td><td>45.13</td>`; find the label, then read the number out of the
    /// next `<td>…</td>`. Returns nil when the row is absent (no-data pixel or out-of-window date).
    static func parseFWI(_ html: String) -> Double? {
        guard let labelEnd = html.range(of: "Fire Weather Index (FWI)")?.upperBound,
              let open = html.range(of: "<td>", range: labelEnd..<html.endIndex),
              let close = html.range(of: "</td>", range: open.upperBound..<html.endIndex) else { return nil }
        let value = html[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(value)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
