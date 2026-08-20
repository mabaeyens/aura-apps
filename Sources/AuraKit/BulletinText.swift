import Foundation

/// Presentation helper for the AEMET narrative bulletin. AEMET writes the "PREDICCIÓN" section as one
/// run-on paragraph with hard column wraps baked in (a newline mid-sentence, often with a leading
/// space). Rendered verbatim it reads as a wall of ragged text — "descenso en el⏎ resto". This flows
/// it back out and breaks it into one line per sentence, since each sentence is its own topic (sky,
/// rain, max temps, min temps, wind), which is far easier to scan on both the phone and the watch.
public enum BulletinText {
    /// The bulletin as one line per sentence, with every hard wrap collapsed to a single space first.
    public static func sentences(_ text: String) -> [String] {
        // Collapse ALL whitespace runs — spaces, tabs and AEMET's mid-sentence newlines — to a single
        // space, so the text flows regardless of how it was wrapped upstream.
        let flowed = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        // One line per sentence: a break after each ". " sentence boundary. AEMET prose has no
        // mid-sentence abbreviations and writes decimals with commas, so "." reliably ends a sentence.
        return flowed
            .replacingOccurrences(of: ". ", with: ".\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
