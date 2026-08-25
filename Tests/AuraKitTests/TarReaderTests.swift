import XCTest
@testable import AuraKit

/// M1 coverage for the hand-rolled ustar reader that unpacks AEMET's avisos `.tar`, plus the
/// tar → CAP end-to-end path that turns that payload into `WeatherAlert`s. This is the binary/parse
/// surface that feeds every aviso card, notification and complication, so an off-by-one in the
/// block/size math would silently drop or corrupt warnings with no other signal.
final class TarReaderTests: XCTestCase {

    // MARK: - Fixture builders

    private let block = 512

    /// A 512-byte ustar header with `name` at offset 0 and the octal `size` at offset 124.
    private func header(name: String, size: Int) -> Data {
        var h = Data(count: block)
        let nameBytes = Array(name.utf8.prefix(100))
        h.replaceSubrange(0..<nameBytes.count, with: nameBytes)
        let octal = Array(String(size, radix: 8).utf8.prefix(11))
        h.replaceSubrange(124..<(124 + octal.count), with: octal)
        return h
    }

    /// A header whose size field holds an arbitrary (possibly non-octal) string, to exercise the
    /// `Int(sizeField, radix: 8) ?? 0` fallback.
    private func header(name: String, rawSize: String) -> Data {
        var h = Data(count: block)
        let nameBytes = Array(name.utf8.prefix(100))
        h.replaceSubrange(0..<nameBytes.count, with: nameBytes)
        let raw = Array(rawSize.utf8.prefix(11))
        h.replaceSubrange(124..<(124 + raw.count), with: raw)
        return h
    }

    private func padded(_ body: Data) -> Data {
        var d = body
        let rem = body.count % block
        if rem != 0 { d.append(Data(count: block - rem)) }
        return d
    }

    private func zeroBlock() -> Data { Data(count: block) }

    /// A well-formed archive: each entry's header + padded body, then a terminating zero block.
    private func archive(_ entries: [(name: String, body: Data)]) -> Data {
        var d = Data()
        for e in entries { d.append(header(name: e.name, size: e.body.count)); d.append(padded(e.body)) }
        d.append(zeroBlock())
        return d
    }

    // MARK: - TarReader unit

    func testSingleEntryExtracted() {
        let body = Data("hello".utf8)
        let files = TarReader.files(from: archive([("a.xml", body)]))
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.first?.name, "a.xml")
        XCTAssertEqual(files.first?.body, body)
    }

    func testMultipleEntriesInOrder() {
        let files = TarReader.files(from: archive([
            ("first.xml", Data("uno".utf8)),
            ("second.xml", Data("dos".utf8)),
        ]))
        XCTAssertEqual(files.map(\.name), ["first.xml", "second.xml"])
        XCTAssertEqual(files.map { String(decoding: $0.body, as: UTF8.self) }, ["uno", "dos"])
    }

    func testBodyNotMultipleOf512StillAdvancesToNextEntry() {
        // First body is 5 bytes (well under a block); the reader must skip the full 512-byte padded
        // slot and still find the entry after it.
        let files = TarReader.files(from: archive([
            ("small.xml", Data("12345".utf8)),
            ("next.xml", Data("after".utf8)),
        ]))
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files[0].body, Data("12345".utf8))
        XCTAssertEqual(files[1].name, "next.xml")
    }

    func testZeroSizeEntrySkippedWithoutInfiniteLoop() {
        // A zero-size entry advances by exactly one block and is not emitted (size > 0 gate).
        var d = Data()
        d.append(header(name: "empty.xml", size: 0))
        d.append(header(name: "real.xml", size: Data("ok".utf8).count))
        d.append(padded(Data("ok".utf8)))
        d.append(zeroBlock())
        let files = TarReader.files(from: d)
        XCTAssertEqual(files.map(\.name), ["real.xml"])
    }

    func testTruncatedBodyIsDropped() {
        // Header claims 1000 bytes but only 100 follow: offset + size > count, so the entry is skipped
        // and the reader returns without crashing.
        var d = header(name: "truncated.xml", size: 1000)
        d.append(Data(count: 100))
        XCTAssertTrue(TarReader.files(from: d).isEmpty)
    }

    func testCorruptSizeFieldDefaultsToZero() {
        // A non-octal size field parses as 0, so the entry is skipped and the loop still terminates.
        var d = header(name: "garbage.xml", rawSize: "ZZZZ")
        d.append(zeroBlock())
        XCTAssertTrue(TarReader.files(from: d).isEmpty)
    }

    func testEmptyAndSubBlockInputReturnEmpty() {
        XCTAssertTrue(TarReader.files(from: Data()).isEmpty)
        XCTAssertTrue(TarReader.files(from: Data(count: 100)).isEmpty)   // shorter than one block
        XCTAssertTrue(TarReader.files(from: zeroBlock()).isEmpty)        // immediate end-of-archive
    }

    // MARK: - Avisos end-to-end (tar -> CAP -> WeatherAlert)

    func testAvisosTarDecodesThroughCAPParser() {
        let cap = """
        <?xml version="1.0" encoding="UTF-8"?>
        <alert xmlns="urn:oasis:names:tc:emergency:cap:1.2">
          <info>
            <language>es-ES</language>
            <event>Aviso de temperaturas máximas de nivel naranja</event>
            <onset>2026-08-25T10:00:00+02:00</onset>
            <expires>2026-08-25T20:00:00+02:00</expires>
            <parameter>
              <valueName>AEMET-Meteoalerta nivel</valueName><value>naranja</value>
            </parameter>
            <parameter>
              <valueName>AEMET-Meteoalerta parametro</valueName><value>BT;Temperatura máxima;35</value>
            </parameter>
            <area>
              <areaDesc>Valle del Almanzora y Los Vélez</areaDesc>
              <geocode>
                <valueName>AEMET-Meteoalerta zona</valueName><value>610401</value>
              </geocode>
            </area>
          </info>
        </alert>
        """
        let tar = archive([("Z_CAP_C_LEMM_avisos.xml", Data(cap.utf8))])

        let files = TarReader.files(from: tar)
        XCTAssertEqual(files.count, 1)

        let alerts = CAPParser.parse(files[0].body)
        XCTAssertEqual(alerts.count, 1)
        let a = alerts[0]
        XCTAssertEqual(a.level, .naranja)
        XCTAssertEqual(a.zona, "610401")
        XCTAssertEqual(a.provinceCode, "04")                 // Almería, digits 3 and 4 of the zone
        XCTAssertEqual(a.phenomenon, "Temperatura máxima")   // middle component of `parametro`
        XCTAssertEqual(a.areaDesc, "Valle del Almanzora y Los Vélez")
        XCTAssertEqual(a.shortLabel, "Calor")
        XCTAssertNotNil(a.onset)
        XCTAssertNotNil(a.expires)
    }

    func testCAPParserIgnoresNonSpanishInfoBlock() {
        let cap = """
        <alert xmlns="urn:oasis:names:tc:emergency:cap:1.2">
          <info>
            <language>en-GB</language>
            <event>Maximum temperature warning</event>
            <parameter><valueName>AEMET-Meteoalerta nivel</valueName><value>naranja</value></parameter>
            <area>
              <areaDesc>Zone</areaDesc>
              <geocode><valueName>AEMET-Meteoalerta zona</valueName><value>610401</value></geocode>
            </area>
          </info>
        </alert>
        """
        XCTAssertTrue(CAPParser.parse(Data(cap.utf8)).isEmpty)
    }
}
