import Foundation

/// Minimal reader for uncompressed (ustar) tar archives — enough to pull the CAP-XML files out of
/// AEMET's avisos payload, which is a plain `.tar` (not gzipped). Each entry is a 512-byte header
/// followed by the file body padded up to the next 512-byte boundary; two zero blocks end the
/// archive.
enum TarReader {
    static func files(from data: Data) -> [(name: String, body: Data)] {
        let block = 512
        var result: [(String, Data)] = []
        var offset = 0
        while offset + block <= data.count {
            let header = data.subdata(in: offset..<offset + block)
            if header.allSatisfy({ $0 == 0 }) { break }   // end-of-archive marker
            let name = string(header, at: 0, length: 100)
            let sizeField = string(header, at: 124, length: 12)
                .trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
            let size = Int(sizeField, radix: 8) ?? 0
            offset += block
            if !name.isEmpty, size > 0, offset + size <= data.count {
                result.append((name, data.subdata(in: offset..<offset + size)))
            }
            offset += (size + block - 1) / block * block   // skip body, padded to 512
        }
        return result
    }

    /// A NUL-terminated ASCII field from a 512-byte header block (indices are 0-based within it).
    private static func string(_ header: Data, at start: Int, length: Int) -> String {
        let bytes = header[start..<start + length].prefix { $0 != 0 }
        return String(decoding: bytes, as: UTF8.self)
    }
}
