import Foundation

/// The official narrative forecast for an autonomous community, as issued by an AEMET
/// forecaster and served from the OpenData normalized-text products (`ascii/txt`).
public struct ForecastBulletin: Sendable, Codable {
    /// When AEMET produced this bulletin (from the "DÍA … A LAS … HORA OFICIAL" header).
    public let elaborado: Date?
    /// The day the bulletin is valid for (from the "PREDICCIÓN VÁLIDA PARA …" header).
    public let validezInicio: Date?
    /// End of the validity window. AEMET's daily bulletins cover a single day, so this is nil.
    public let validezFin: Date?
    /// Significant phenomena (section "A.- FENÓMENOS SIGNIFICATIVOS"), or nil when none are expected.
    public let fenomenoSignificativo: String?
    /// The main narrative text (section "B.- PREDICCIÓN"), hard wraps unfolded into paragraphs.
    public let texto: String

    public init(elaborado: Date?, validezInicio: Date?, validezFin: Date?,
                fenomenoSignificativo: String?, texto: String) {
        self.elaborado = elaborado
        self.validezInicio = validezInicio
        self.validezFin = validezFin
        self.fenomenoSignificativo = fenomenoSignificativo
        self.texto = texto
    }
}

/// AEMET's national medium-range forecast (`/prediccion/nacional/medioplazo`). Unlike the day products it
/// has no A.-/B.- sections, just one free-narrative block per day, so each block is kept separate and the
/// card can show one dated section per day.
public struct MedioplazoForecast: Sendable, Codable {
    /// One day's block: the day-of-month, its Spanish weekday name (as AEMET writes it), and the narrative.
    public struct Day: Sendable, Codable {
        public let day: Int
        public let weekday: String
        public let texto: String
        public init(day: Int, weekday: String, texto: String) {
            self.day = day; self.weekday = weekday; self.texto = texto
        }
    }
    /// When AEMET produced this bulletin (from the "DÍA … A LAS … HORA OFICIAL" header).
    public let elaborado: Date?
    /// The raw "PREDICCIÓN VÁLIDA PARA LOS DÍAS …" line, shown verbatim as the validity note.
    public let validez: String?
    /// One block per day, in feed order.
    public let days: [Day]
    public init(elaborado: Date?, validez: String?, days: [Day]) {
        self.elaborado = elaborado; self.validez = validez; self.days = days
    }
}

public extension AEMETClient {
    /// The official community narrative that covers *today*, from AEMET's OpenData text products.
    ///
    /// AEMET's `hoy` product is an *amendment* channel — it is only re-issued when conditions
    /// change significantly intraday, so on a quiet day it can name a date days back. The forecast
    /// that actually covers today was issued *yesterday* as the daily `manana` product. So this
    /// prefers today's `hoy` when AEMET issued one valid for today, and otherwise reads yesterday's
    /// `manana` from the archive (`…/elaboracion/{ayer}`), which is guaranteed to cover today.
    ///
    /// `comunidad.code` is AEMET's community code (e.g. "mad", "gal"). `date` defaults to now,
    /// interpreted in Spanish peninsular civil time (the reference AEMET stamps its bulletins in).
    func comunidadBulletin(_ comunidad: Comunidad, on date: Date = Date()) async throws -> ForecastBulletin {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = AEMETBulletinParser.madrid
        let today = calendar.startOfDay(for: date)

        // 1. Prefer an intraday `hoy` amendment, but only if it is actually valid for today.
        if let text = try? await fetchText("/prediccion/ccaa/hoy/\(comunidad.code)"),
           let hoy = AEMETBulletinParser.parse(text),
           let validez = hoy.validezInicio, calendar.isDate(validez, inSameDayAs: today) {
            return hoy
        }

        // 2. Otherwise, yesterday's `manana` is today's forecast.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let elaboracion = Self.archiveDayFormatter.string(from: yesterday)
        let text = try await fetchText("/prediccion/ccaa/manana/\(comunidad.code)/elaboracion/\(elaboracion)")
        guard let bulletin = AEMETBulletinParser.parse(text) else {
            throw ClientError.decoding("community bulletin text was not in the expected format")
        }
        return bulletin
    }

    /// `yyyy-MM-dd` in Spanish peninsular time, for the archive endpoint's `elaboracion` segment.
    private static let archiveDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = AEMETBulletinParser.madrid
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

/// Parses AEMET's normalized-text community bulletin (a small fixed-layout `ascii/txt` document):
///
///     AGENCIA ESTATAL DE METEOROLOGÍA
///     PREDICCIÓN GENERAL PARA LA COMUNIDAD DE …
///     DÍA 18 DE AGOSTO DE 2026 A LAS 12:38 HORA OFICIAL
///     PREDICCIÓN VÁLIDA PARA EL MIÉRCOLES 19
///
///     A.- FENÓMENOS SIGNIFICATIVOS
///     …
///
///     B.- PREDICCIÓN
///     …
///
/// Lines are hard-wrapped to a narrow column; each section's wraps are unfolded back into flowing
/// paragraphs (blank lines separate paragraphs; single newlines are wraps).
enum AEMETBulletinParser {
    static let madrid = TimeZone(identifier: "Europe/Madrid") ?? .current

    static func parse(_ raw: String) -> ForecastBulletin? {
        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let issueLine = lines.first { $0.uppercased().contains("HORA OFICIAL") }
        let validezLine = lines.first { $0.uppercased().hasPrefix("PREDICCIÓN VÁLIDA") }

        // Split the body into the "A.-" and "B.-" sections.
        guard let aIndex = lines.firstIndex(where: { $0.hasPrefix("A.-") }) else { return nil }
        let bIndex = lines.firstIndex(where: { $0.hasPrefix("B.-") })

        let aBody = bIndex.map { Array(lines[(aIndex + 1)..<$0]) } ?? Array(lines[(aIndex + 1)...])
        let bBody = bIndex.map { Array(lines[($0 + 1)...]) } ?? []

        let elaborado = issueLine.flatMap(issueDate(from:))
        let validez = validezLine.flatMap { validezDate(from: $0, reference: elaborado) }

        let fenomeno = unfold(aBody)
        let texto = unfold(bBody)
        guard !texto.isEmpty else { return nil }

        return ForecastBulletin(
            elaborado: elaborado,
            validezInicio: validez,
            validezFin: nil,
            fenomenoSignificativo: isNoPhenomena(fenomeno) ? nil : fenomeno,
            texto: texto
        )
    }

    /// Parse the national medium-range product (`/prediccion/nacional/medioplazo`). It has no A.-/B.-
    /// sections: after the header it is one free-narrative block per day, each introduced by a
    /// `DÍA NN (WEEKDAY)` line (two-digit day, uppercase weekday in parentheses). Blocks are split on that
    /// header and each block's lines are unfolded into flowing paragraphs. Returns nil if no day block is
    /// found (an unexpected layout), so the caller can drop the segment rather than show a blank.
    static func parseMedioplazo(_ raw: String) -> MedioplazoForecast? {
        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let elaborado = lines.first { $0.uppercased().contains("HORA OFICIAL") }.flatMap(issueDate(from:))
        let validez = lines.first { $0.uppercased().hasPrefix("PREDICCIÓN VÁLIDA") }

        var days: [MedioplazoForecast.Day] = []
        var currentDay: Int?
        var currentWeekday: String?
        var buffer: [String] = []

        func flush() {
            if let day = currentDay, let weekday = currentWeekday {
                let texto = unfold(buffer)
                if !texto.isEmpty { days.append(.init(day: day, weekday: weekday, texto: texto)) }
            }
            buffer.removeAll()
        }

        for line in lines {
            // The lines are already trimmed, so the header's leading space is gone; match `DÍA NN (NOMBRE)`.
            if let match = line.firstMatch(of: /^D[IÍ]A\s+(\d{1,2})\s+\(([^)]+)\)$/.ignoresCase()),
               let day = Int(match.1) {
                flush()
                currentDay = day
                currentWeekday = String(match.2).capitalized
            } else if currentDay != nil {
                buffer.append(line)
            }
        }
        flush()

        guard !days.isEmpty else { return nil }
        return MedioplazoForecast(elaborado: elaborado, validez: validez, days: days)
    }

    /// Unfold hard-wrapped lines: blank lines delimit paragraphs; within a paragraph the wraps
    /// are joined with spaces. Paragraphs are rejoined with a blank line.
    private static func unfold(_ lines: [String]) -> String {
        var paragraphs: [String] = []
        var current: [String] = []
        for line in lines {
            if line.isEmpty {
                if !current.isEmpty { paragraphs.append(current.joined(separator: " ")); current = [] }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { paragraphs.append(current.joined(separator: " ")) }
        return paragraphs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when section A says there are no significant phenomena (e.g. "No se esperan.").
    private static func isNoPhenomena(_ text: String) -> Bool {
        let low = text.lowercased()
        if low.isEmpty { return true }
        return low.hasPrefix("no se esperan")
            || low.contains("sin fenómenos")
            || low.contains("no hay fenómenos")
            || low.contains("ningún fenómeno")
    }

    private static let months: [String: Int] = [
        "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6,
        "julio": 7, "agosto": 8, "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12,
    ]

    /// Parse "DÍA 18 DE AGOSTO DE 2026 A LAS 12:38 HORA OFICIAL".
    private static func issueDate(from line: String) -> Date? {
        guard let match = line.firstMatch(of:
            /D[IÍ]A\s+(\d{1,2})\s+DE\s+(\p{L}+)\s+DE\s+(\d{4})\s+A\s+LAS\s+(\d{1,2}):(\d{2})/
                .ignoresCase()
        ) else { return nil }

        guard let day = Int(match.1),
              let month = months[String(match.2).lowercased()],
              let year = Int(match.3),
              let hour = Int(match.4),
              let minute = Int(match.5) else { return nil }

        return date(year: year, month: month, day: day, hour: hour, minute: minute)
    }

    /// Parse the validity day from "PREDICCIÓN VÁLIDA PARA EL MIÉRCOLES 19"; the month/year come
    /// from the issue date (rolling to the next month when the validity day precedes the issue day).
    private static func validezDate(from line: String, reference: Date?) -> Date? {
        guard let reference,
              let match = line.firstMatch(of: /(\d{1,2})\s*$/),
              let validDay = Int(match.1) else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = madrid
        let parts = calendar.dateComponents([.year, .month, .day], from: reference)
        guard var year = parts.year, var month = parts.month, let issueDay = parts.day else { return nil }
        if validDay < issueDay { // crossed into the next month
            month += 1
            if month > 12 { month = 1; year += 1 }
        }
        return date(year: year, month: month, day: validDay, hour: 0, minute: 0)
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = madrid
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        return calendar.date(from: comps)
    }
}

/// The horizon of a day-scoped national bulletin (`hoy` / `manana` / `pasadomanana`). `medioplazo` is a
/// different document with its own parser, so it is not a case here.
public enum NationalDay: Sendable { case hoy, manana, pasadoManana }

public extension AEMETClient {
    /// Raw national normalized-text products (España-level), the counterpart of the per-community `hoy`
    /// text. Same `text/plain` two-step envelope as every other product, served by `fetchText`.
    func prediccionNacionalHoy() async throws -> String { try await fetchText("/prediccion/nacional/hoy") }
    func prediccionNacionalManana() async throws -> String { try await fetchText("/prediccion/nacional/manana") }
    func prediccionNacionalPasadoManana() async throws -> String { try await fetchText("/prediccion/nacional/pasadomanana") }
    func prediccionNacionalMedioplazo() async throws -> String { try await fetchText("/prediccion/nacional/medioplazo") }

    /// A day-scoped national bulletin, parsed from the same A.-/B.- normalized text as the community
    /// bulletin. This fetches and parses a single horizon; the amendment-only `hoy` resolve (accept only
    /// when valid for today, otherwise fall back to `manana`) lives in the app's `NationalTextService`, so
    /// each horizon's fetch stays independently cached instead of `hoy` pulling `manana` behind its cache.
    func nacionalBulletin(_ day: NationalDay) async throws -> ForecastBulletin {
        let text: String
        switch day {
        case .hoy:          text = try await prediccionNacionalHoy()
        case .manana:       text = try await prediccionNacionalManana()
        case .pasadoManana: text = try await prediccionNacionalPasadoManana()
        }
        guard let bulletin = AEMETBulletinParser.parse(text) else {
            throw ClientError.decoding("national bulletin text was not in the expected format")
        }
        return bulletin
    }

    /// The national medium-range forecast, split into one block per day on the `DÍA NN (WEEKDAY)` headers.
    func nacionalMedioplazo() async throws -> MedioplazoForecast {
        let text = try await prediccionNacionalMedioplazo()
        guard let forecast = AEMETBulletinParser.parseMedioplazo(text) else {
            throw ClientError.decoding("national medium-range text was not in the expected format")
        }
        return forecast
    }
}
