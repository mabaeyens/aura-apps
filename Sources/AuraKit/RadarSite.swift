import Foundation

/// One of AEMET's 15 regional weather radars. Each regional image is a ~240 km-radius circle centred on
/// the radar site, so picking the nearest site to a location gives an image that's already "local" — no
/// cropping or georeferencing needed. Coordinates are the radar cities (close enough for nearest-site
/// selection; the true antenna sites differ by a few km).
public struct RadarSite: Sendable, Hashable {
    /// AEMET regional radar code, e.g. "ma" for Madrid.
    public let code: String
    /// Human name for the card subtitle, e.g. "Madrid".
    public let name: String
    public let latitude: Double
    public let longitude: Double

    public init(code: String, name: String, latitude: Double, longitude: Double) {
        self.code = code; self.name = name; self.latitude = latitude; self.longitude = longitude
    }

    /// All 15 regional radars.
    public static let all: [RadarSite] = [
        RadarSite(code: "am", name: "Almería",       latitude: 36.83, longitude: -2.46),
        RadarSite(code: "sa", name: "Asturias",      latitude: 43.43, longitude: -6.30),
        RadarSite(code: "pm", name: "Illes Balears", latitude: 39.57, longitude:  2.65),
        RadarSite(code: "ba", name: "Barcelona",     latitude: 41.39, longitude:  2.16),
        RadarSite(code: "cc", name: "Cáceres",       latitude: 39.47, longitude: -6.37),
        RadarSite(code: "co", name: "A Coruña",      latitude: 43.37, longitude: -8.40),
        RadarSite(code: "ma", name: "Madrid",        latitude: 40.42, longitude: -3.70),
        RadarSite(code: "ml", name: "Málaga",        latitude: 36.72, longitude: -4.42),
        RadarSite(code: "mu", name: "Murcia",        latitude: 37.99, longitude: -1.13),
        RadarSite(code: "vd", name: "Palencia",      latitude: 42.01, longitude: -4.53),
        RadarSite(code: "ca", name: "Las Palmas",    latitude: 28.10, longitude: -15.41),
        RadarSite(code: "se", name: "Sevilla",       latitude: 37.39, longitude: -5.99),
        RadarSite(code: "va", name: "Valencia",      latitude: 39.47, longitude: -0.38),
        RadarSite(code: "ss", name: "Vizcaya",       latitude: 43.26, longitude: -2.93),
        RadarSite(code: "za", name: "Zaragoza",      latitude: 41.65, longitude: -0.89),
    ]

    /// The nearest radar site to a location (great-circle). Never nil — the list is non-empty.
    public static func nearest(toLatitude lat: Double, longitude lon: Double) -> RadarSite {
        all.min { a, b in
            haversine(lat, lon, a.latitude, a.longitude) < haversine(lat, lon, b.latitude, b.longitude)
        } ?? all[0]
    }

    private static func haversine(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6371.0, p = Double.pi / 180
        let dLat = (lat2 - lat1) * p, dLon = (lon2 - lon1) * p
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * p) * cos(lat2 * p) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}
