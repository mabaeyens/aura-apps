import XCTest
@testable import AuraKit

final class ForecastPhraseTests: XCTestCase {

    /// A day at a fixed instant, so time-of-day wording is stable across runs.
    private let noon = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func snap(sky: String? = "11", min: Int? = 15, max: Int? = 24,
                      humidity: Int? = 63, precip: Int? = 10,
                      wind: Int? = 9, dir: WindDirection? = .o,
                      mm: Double? = nil, snow: Double? = nil, feels: Int? = nil, storm: Int? = nil,
                      city: String = "Bilbao") -> WeatherSnapshot {
        WeatherSnapshot(ine: "48020", localidad: city, provincia: "Bizkaia",
                        tempMin: min, tempMax: max, humedadMax: humidity,
                        currentTemp: 21, currentSky: sky, currentSkyText: "Nuboso",
                        currentHumidity: humidity, currentPrecipProb: precip,
                        currentPrecipMm: mm, currentSnowMm: snow,
                        currentFeelsLike: feels, currentStormProb: storm,
                        windSpeed: wind, windDirection: dir,
                        sunrise: nil, sunset: nil, updated: Date(timeIntervalSince1970: 0))
    }

    // MARK: Accuracy — the data can never be misstated

    func testDatalineCarriesEveryKnownNumber() {
        let line = ForecastPhrase.dataline(for: snap(min: 15, max: 24, humidity: 63, precip: 10,
                                                     wind: 9, dir: .o), now: noon)
        XCTAssertTrue(line.contains("15°"), line)
        XCTAssertTrue(line.contains("24°"), line)
        XCTAssertTrue(line.contains("9 km/h"), line)
        XCTAssertTrue(line.lowercased().contains("oeste"), line)
        XCTAssertTrue(line.contains("63%"), line)
        XCTAssertTrue(line.contains("10%"), line)
    }

    func testDatalineDryDaySaysSoAndShowsNoRainPercent() {
        // precip 0 → an explicit dry sentence, and no "0%" rain figure leaks in.
        for day in 0..<20 {
            let line = ForecastPhrase.dataline(for: snap(precip: 0),
                                               now: noon.addingTimeInterval(Double(day) * 86_400))
            XCTAssertFalse(line.contains("0%"), line)
            let dry = ["sin lluvia", "no se espera lluvia", "jornada seca"]
            XCTAssertTrue(dry.contains { line.lowercased().contains($0) }, line)
        }
    }

    func testDatalineDegradesWhenFieldsMissing() {
        // No temps, no humidity, only wind + rain — still a clean sentence, no dangling punctuation.
        let line = ForecastPhrase.dataline(
            for: snap(min: nil, max: nil, humidity: nil, precip: 40, wind: 12, dir: .ne), now: noon)
        XCTAssertFalse(line.isEmpty)
        XCTAssertFalse(line.contains(" ,"), line)
        XCTAssertFalse(line.contains("..."), line)
        XCTAssertTrue(line.contains("40%"), line)
    }

    // MARK: Rain amount (mm), feels-like, storm

    func testDatalineShowsRainAmountWhenMeaningful() {
        let line = ForecastPhrase.dataline(for: snap(precip: 75, mm: 2), now: noon)
        XCTAssertTrue(line.contains("75%"), line)
        XCTAssertTrue(line.contains("2 mm"), line)   // whole number, no decimal
    }

    func testDatalineFormatsFractionalMmWithComma() {
        let line = ForecastPhrase.dataline(for: snap(precip: 60, mm: 0.4), now: noon)
        XCTAssertTrue(line.contains("0,4 mm"), line)
        XCTAssertFalse(line.contains("0.4"), line)   // Spanish decimal comma, never a dot
    }

    func testDatalineOmitsTraceAndZeroMm() {
        for amount in [0.0, 0.05] {
            let line = ForecastPhrase.dataline(for: snap(precip: 20, mm: amount), now: noon)
            XCTAssertFalse(line.lowercased().contains("mm"), "\(amount): \(line)")
        }
    }

    func testDatalineShowsSnowAmountOnSnowyDays() {
        let line = ForecastPhrase.dataline(for: snap(sky: "34", precip: 80, snow: 3), now: noon)  // 34 = snow
        XCTAssertTrue(line.lowercased().contains("3 mm de nieve"), line)
    }

    func testDatalineOmitsTraceSnow() {
        let line = ForecastPhrase.dataline(for: snap(snow: 0.0), now: noon)
        XCTAssertFalse(line.lowercased().contains("nieve"), line)
    }

    func testDatalineShowsStormRiskWhenLikely() {
        let line = ForecastPhrase.dataline(for: snap(precip: 40, storm: 55), now: noon)
        XCTAssertTrue(line.lowercased().contains("tormenta"), line)
        XCTAssertTrue(line.contains("55%"), line)
    }

    func testDatalineShowsFeelsLikeOnlyWhenItDiverges() {
        // currentTemp is 21 in the helper; 30 diverges (≥3) → shown, 22 does not.
        let diverges = ForecastPhrase.dataline(for: snap(feels: 30), now: noon)
        XCTAssertTrue(diverges.lowercased().contains("sensación de 30°"), diverges)
        for day in 0..<12 {
            let close = ForecastPhrase.dataline(for: snap(feels: 22),
                                                now: noon.addingTimeInterval(Double(day) * 86_400))
            XCTAssertFalse(close.lowercased().contains("sensación"), close)
        }
    }

    func testPrecipAmountParsing() {
        XCTAssertEqual(WeatherSnapshot.precipAmount("0"), 0)
        XCTAssertEqual(WeatherSnapshot.precipAmount("0.4"), 0.4)
        XCTAssertEqual(WeatherSnapshot.precipAmount("1,2"), 1.2)
        XCTAssertEqual(WeatherSnapshot.precipAmount("Ip"), 0)   // trace reads as 0
        XCTAssertNil(WeatherSnapshot.precipAmount(""))
        XCTAssertNil(WeatherSnapshot.precipAmount("—"))
    }

    // MARK: Headline rules

    func testHeadlineNamesRainWhenRainy() {
        let line = ForecastPhrase.headline(for: snap(sky: "26"), now: noon)  // 26 = rain
        XCTAssertTrue(line.lowercased().contains("lluvi") || line.lowercased().contains("chubasc"), line)
    }

    func testHeadlineMentionsWindOnlyWhenNoticeable() {
        // Force 4 (25 km/h) from the NE → the direction is named.
        let windy = ForecastPhrase.headline(for: snap(sky: "11", wind: 25, dir: .ne), now: noon)
        XCTAssertTrue(windy.lowercased().contains("nordeste"), windy)
        // Near-calm (3 km/h, force 1) → no wind direction in the headline.
        for day in 0..<12 {
            let calm = ForecastPhrase.headline(for: snap(sky: "11", wind: 3, dir: .ne),
                                               now: noon.addingTimeInterval(Double(day) * 86_400))
            XCTAssertFalse(calm.lowercased().contains("del "), calm)
        }
    }

    func testHeadlineIsAProperSentence() {
        let line = ForecastPhrase.headline(for: snap(), now: noon)
        XCTAssertEqual(line.first, line.first?.uppercased().first)
        XCTAssertTrue(line.hasSuffix("."), line)
    }

    // MARK: Determinism + variety

    func testSameInputIsReproducible() {
        let a = ForecastPhrase.headline(for: snap(), now: noon)
        let b = ForecastPhrase.headline(for: snap(), now: noon)
        XCTAssertEqual(a, b)
    }

    func testVariesDayToDay() {
        var seen = Set<String>()
        for day in 0..<14 {
            seen.insert(ForecastPhrase.headline(for: snap(),
                        now: noon.addingTimeInterval(Double(day) * 86_400)))
        }
        XCTAssertGreaterThan(seen.count, 2, "expected several distinct phrasings across a fortnight")
    }

    func testVariesByLocation() {
        let bilbao = ForecastPhrase.dataline(for: snap(city: "Bilbao"), now: noon)
        let sevilla = ForecastPhrase.dataline(for: snap(city: "Sevilla"), now: noon)
        // Same data, different town — the seed should (usually) reshape at least one of the two lines.
        XCTAssertNotEqual(bilbao + ForecastPhrase.headline(for: snap(city: "Bilbao"), now: noon),
                          sevilla + ForecastPhrase.headline(for: snap(city: "Sevilla"), now: noon))
    }
}
