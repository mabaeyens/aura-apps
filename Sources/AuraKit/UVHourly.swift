import Foundation

/// One hour of the CAMS UV forecast (via Open-Meteo): the instant, the forecast UV index — which
/// includes the attenuation from forecast cloud — and the clear-sky UV index for the same hour.
public struct UVHourSlot: Codable, Sendable, Hashable, Identifiable {
    /// The hour's instant (UTC epoch from Open-Meteo; render in the location's zone).
    public let date: Date
    /// Forecast UV index for the hour, cloud effect included.
    public let uv: Double
    /// What the UV index would be under a cloudless sky at the same place and hour.
    public let clearSky: Double

    public init(date: Date, uv: Double, clearSky: Double) {
        self.date = date
        self.uv = uv
        self.clearSky = clearSky
    }

    public var id: Date { date }
    /// Rounded to the whole WHO 0–11+ index the cards and bands use.
    public var index: Int { Int(uv.rounded()) }
}

/// CAMS (Copernicus Atmosphere Monitoring Service) UV forecast, fetched per-coordinate from
/// Open-Meteo's free Air Quality API. This is the **hourly** UV index AEMET's OpenData doesn't publish
/// — AEMET gives only a forecast clear-sky **daily maximum** (see `UVIndex`), so Aura keeps that as the
/// official headline and shows this hourly curve alongside it. CAMS models surface UV from ozone,
/// aerosols and forecast cloud; it's the same source dedicated UV services use for an hourly curve.
///
/// **Attribution (required):** data © CAMS / Copernicus (CC BY 4.0) via Open-Meteo — credit both,
/// next to the existing AEMET + MITECO line.
///
/// **Licence note:** Open-Meteo's *free* endpoint is for non-commercial use (≤10k calls/day, enforced
/// per client IP). Aura calls it directly from each device, so every install has its own budget and
/// makes only a few calls a day — the cap is never in reach. The CAMS data itself is CC BY 4.0, so if
/// Aura ever monetises, move to Open-Meteo's customer endpoint (`customer-api.open-meteo.com` + key)
/// or self-host the open-source server against CAMS. Full findings: `docs/UVI_OBSERVED.md`.
public enum OpenMeteoUV {
    /// The free Air Quality endpoint for a point: two days of hourly `uv_index` (+ clear-sky), with
    /// times as UTC epochs (`unixtime`) and day-bucketing in the location's own zone (`timezone=auto`).
    static func feedURL(latitude lat: Double, longitude lon: Double) -> URL? {
        var c = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")
        c?.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "hourly", value: "uv_index,uv_index_clear_sky"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "2"),
        ]
        return c?.url
    }

    private struct Response: Decodable {
        let hourly: Hourly
        struct Hourly: Decodable {
            let time: [Int]
            let uv_index: [Double?]
            let uv_index_clear_sky: [Double?]
        }
    }

    /// Today + tomorrow's hourly UV for a point, or `[]` on any failure — this never throws, so a UV
    /// outage just hides the hourly curve, exactly like the air-quality card on a MITECO outage.
    public static func fetch(latitude lat: Double, longitude lon: Double,
                             session: URLSession = .shared) async -> [UVHourSlot] {
        guard let url = feedURL(latitude: lat, longitude: lon) else { return [] }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            let h = try JSONDecoder().decode(Response.self, from: data).hourly
            var slots: [UVHourSlot] = []
            slots.reserveCapacity(h.time.count)
            for (i, t) in h.time.enumerated() {
                let uv = (i < h.uv_index.count ? h.uv_index[i] : nil) ?? 0
                let clear = (i < h.uv_index_clear_sky.count ? h.uv_index_clear_sky[i] : nil) ?? uv
                slots.append(UVHourSlot(date: Date(timeIntervalSince1970: TimeInterval(t)),
                                        uv: max(0, uv), clearSky: max(0, clear)))
            }
            return slots
        } catch {
            return []
        }
    }
}

public extension Array where Element == UVHourSlot {
    /// The slot covering `now` — the hour-long window `[date, date+1h)` that contains it — for a live
    /// "UV ahora" reading. Timezone-free by construction: it compares absolute instants, so it's right
    /// wherever the viewer is. Nil when `now` falls outside the fetched span (e.g. a stale snapshot).
    func current(at now: Date = Date()) -> UVHourSlot? {
        first { $0.date <= now && now < $0.date.addingTimeInterval(3600) }
    }

    /// Today's hourly slots. The feed is fetched `timezone=auto`, so its first 24 hours are already the
    /// location's local day starting at 00:00 — this keeps the run up to (and including) tomorrow's
    /// midnight boundary, i.e. today. Falls back to the device day when the run can't be found.
    func todaySlots(reference now: Date = Date()) -> [UVHourSlot] {
        guard let first = first else { return [] }
        // The API aligns hour 0 to the location's local midnight; today is the first 24 of those hours.
        // Anchor on the feed's own start so it's correct regardless of the viewer's zone.
        let end = first.date.addingTimeInterval(24 * 3600)
        let sameDay = filter { $0.date >= first.date && $0.date < end }
        return sameDay.isEmpty ? Array(prefix(24)) : sameDay
    }

    /// The peak forecast-UV hour today, for a "máx hoy" figure drawn from the same series.
    func todayMax(reference now: Date = Date()) -> UVHourSlot? {
        todaySlots(reference: now).max { $0.uv < $1.uv }
    }
}
