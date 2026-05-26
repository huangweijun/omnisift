import Foundation

enum ContentStructure {
    static func normalizeExtractedBody(body: String, title: String?) -> String {
        var normalized = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return normalized
        }

        if normalized.hasPrefix(title) {
            normalized = String(normalized.dropFirst(title.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var lines = normalized.components(separatedBy: "\n")
        while let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines), first.isEmpty {
            lines.removeFirst()
        }
        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == title {
            lines.removeFirst()
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func formattedForAIProcessing(title: String?, body: String) -> String {
        let cleanedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedBody.isEmpty else { return "" }

        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return "Title: \(title)\n\n\(cleanedBody)"
        }
        return cleanedBody
    }

    static func cleanDisplayText(_ value: String?) -> String? {
        guard var text = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }

        if let recovered = recoverAIFields(from: text) {
            return recovered
        }

        text = text
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func recoverAIFields(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), trimmed.contains("\"title\"") else {
            return nil
        }

        if let json = extractBalancedJSONObject(from: trimmed),
           let data = json.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(EmbeddedAIResponseJSON.self, from: data) {
            return parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let title = firstJSONStringValue(named: "title", in: trimmed) {
            return title
        }

        return nil
    }

    static func recoverHighlight(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") else { return nil }
        if let json = extractBalancedJSONObject(from: trimmed),
           let data = json.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(EmbeddedAIResponseJSON.self, from: data) {
            return parsed.highlight?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return firstJSONStringValue(named: "highlight", in: trimmed)
    }

    static func cleanKnowledgeLabel(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("{") {
            return recoverAIFields(from: trimmed)
        }
        return trimmed
    }

    static func preprocessMarkdownForDisplay(_ markdown: String) -> String {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var output: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("|"),
               index + 1 < lines.count,
               lines[index + 1].contains("|"),
               lines[index + 1].contains("-") {
                let headerCells = tableCells(from: trimmed)
                index += 2

                while index < lines.count {
                    let row = lines[index].trimmingCharacters(in: .whitespaces)
                    guard row.contains("|") else { break }
                    let cells = tableCells(from: row)
                    if cells.isEmpty {
                        index += 1
                        continue
                    }

                    if headerCells.count > 1, cells.count == headerCells.count {
                        let pairs = zip(headerCells, cells).map { "**\($0.0)**: \($0.1)" }
                        output.append("- " + pairs.joined(separator: " · "))
                    } else if cells.count >= 2 {
                        output.append("- **\(cells[0])**: \(cells.dropFirst().joined(separator: ", "))")
                    } else {
                        output.append("- \(cells.joined(separator: " · "))")
                    }
                    index += 1
                }
                output.append("")
                continue
            }

            output.append(line)
            index += 1
        }

        return output
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractBalancedJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var isEscaped = false

        for index in text.indices[start...] {
            let character = text[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }

            switch character {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(text[start...index])
                }
            case "\"":
                inString = true
            default:
                break
            }
        }

        return nil
    }

    private static func tableCells(from line: String) -> [String] {
        line
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.allSatisfy { $0 == "-" } }
    }

    private static func firstJSONStringValue(named key: String, in text: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[range])
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct EmbeddedAIResponseJSON: Decodable {
    let title: String
    let highlight: String?
}
