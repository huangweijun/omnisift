import Foundation
import Network

struct SourceURLValidator {
    static func validatedWebURL(from string: String?) -> URL? {
        guard let string,
              let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return validatedWebURL(url)
    }

    static func firstValidatedWebURL(in text: String?) -> URL? {
        guard let text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        for candidate in detectedURLStrings(in: text) {
            if let url = validatedDetectedURLString(candidate) {
                return url
            }
        }

        return nil
    }

    static func validatedWebURL(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.user == nil,
              url.password == nil,
              let host = url.host(percentEncoded: false),
              isPublicHost(host) else {
            return nil
        }
        return url
    }

    private static func isPublicHost(_ host: String) -> Bool {
        let normalizedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        guard !normalizedHost.isEmpty,
              normalizedHost != "localhost",
              !normalizedHost.hasSuffix(".local") else {
            return false
        }

        if normalizedHost.contains(":") {
            return isPublicIPv6Host(normalizedHost)
        }
        if normalizedHost.hasPrefix("0x"),
           normalizedHost.dropFirst(2).allSatisfy(\.isHexDigit) {
            return false
        }
        if normalizedHost.allSatisfy({ $0.isNumber || $0 == "." }) {
            return isPublicIPv4Host(normalizedHost)
        }
        return true
    }

    private static func isPublicIPv4Host(_ host: String) -> Bool {
        let parts = host.split(separator: ".")
        guard parts.count == 4,
              let first = Int(parts[0]),
              let second = Int(parts[1]),
              let third = Int(parts[2]),
              let fourth = Int(parts[3]),
              [first, second, third, fourth].allSatisfy({ (0...255).contains($0) }) else {
            return false
        }

        if first == 0 || first == 10 || first == 127 { return false }
        if first == 100 && (64...127).contains(second) { return false }
        if first == 169 && second == 254 { return false }
        if first == 172 && (16...31).contains(second) { return false }
        if first == 192 && second == 168 { return false }
        if first == 198 && (second == 18 || second == 19) { return false }
        if first >= 224 { return false }
        return true
    }

    private static func isPublicIPv6Host(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard let address = IPv6Address(normalized) else { return false }
        let bytes = address.rawValue
        if bytes.allSatisfy({ $0 == 0 }) { return false }
        if bytes.dropLast().allSatisfy({ $0 == 0 }) && bytes.last == 1 { return false }
        if bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80 { return false }
        if (bytes[0] & 0xfe) == 0xfc { return false }
        if bytes[0...9].allSatisfy({ $0 == 0 }), bytes[10] == 0xff, bytes[11] == 0xff {
            let mappedIPv4 = bytes[12...15].map(String.init).joined(separator: ".")
            return isPublicIPv4Host(mappedIPv4)
        }
        return true
    }

    private static func detectedURLStrings(in text: String) -> [String] {
        var results: [String] = []
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in detector.matches(in: text, options: [], range: range) {
                if let url = match.url?.absoluteString {
                    results.append(url)
                }
                if let textRange = Range(match.range, in: text) {
                    results.append(String(text[textRange]))
                }
            }
        }

        let pattern = #"(?i)\b(?:https?://|www\.)[^\s<>"']+"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                if let textRange = Range(match.range, in: text) {
                    results.append(String(text[textRange]))
                }
            }
        }

        var seen = Set<String>()
        return results.compactMap { raw in
            let cleaned = cleanDetectedURLString(raw)
            guard !cleaned.isEmpty else { return nil }
            let key = cleaned.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return cleaned
        }
    }

    private static func validatedDetectedURLString(_ raw: String) -> URL? {
        var cleaned = cleanDetectedURLString(raw)
        if cleaned.lowercased().hasPrefix("www.") {
            cleaned = "https://\(cleaned)"
        }
        return validatedWebURL(from: cleaned)
    }

    private static func cleanDetectedURLString(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let trailingTerminators = CharacterSet(charactersIn: ".,;:!?)\"]}'")
        while let scalar = cleaned.unicodeScalars.last,
              trailingTerminators.contains(scalar) {
            cleaned.removeLast()
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
