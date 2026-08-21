import XCTest
@testable import AuraKit

final class ForecastPhraseTests: XCTestCase {

    /// A day at a fixed instant, so time-of-day wording is stable across runs.
    private let noon = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func snap(sky: String? = "11", min: Int? = 15, max: Int? = 24,
                      humidity: Int? = 63, precip: Int? = 10,
                      wind: Int? = 9, dir: WindDirection? = .o,
                      city: String = "Bilbao") -> WeatherSnapshot {
        WeatherSnapshot(ine: "48020", localidad: city, provincia: "Bizkaia",
                        tempMin: min, tempMax: max, humedadMax: humidity,
                        currentTemp: 21, currentSky: sky, currentSkyText: "Nuboso",
                        currentHumidity: humidity, currentPrecipProb: precip,
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
