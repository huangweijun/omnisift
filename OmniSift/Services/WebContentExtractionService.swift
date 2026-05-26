import Foundation

actor WebContentExtractionService {
    private let minimumUsefulTextLength = 500

    struct ExtractionResult: Sendable {
        let title: String?
        let text: String
        let status: ExtractionStatus
        let errorMessage: String?
    }

    enum ExtractionError: LocalizedError {
        case invalidURL
        case unsupportedScheme
        case emptyResponse
        case nonHTMLContent

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Invalid source URL"
            case .unsupportedScheme: "Only http and https links can be extracted"
            case .emptyResponse: "The page did not return readable content"
            case .nonHTMLContent: "The link is not a readable web page"
            }
        }
    }

    func extract(from url: URL) async -> ExtractionResult {
        do {
            guard let url = SourceURLValidator.validatedWebURL(url) else {
                throw ExtractionError.unsupportedScheme
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let finalURL = response.url,
                  SourceURLValidator.validatedWebURL(finalURL) != nil else {
                throw ExtractionError.unsupportedScheme
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw ExtractionError.emptyResponse
            }

            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
               !contentType.localizedCaseInsensitiveContains("html") {
                throw ExtractionError.nonHTMLContent
            }

            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                throw ExtractionError.emptyResponse
            }

            let title = extractTitle(from: html)
            let text = extractReadableText(from: html)
            guard !text.isEmpty else {
                throw ExtractionError.emptyResponse
            }

            let status: ExtractionStatus = text.count >= minimumUsefulTextLength ? .fullText : .partialText
            return ExtractionResult(title: title, text: text, status: status, errorMessage: nil)
        } catch {
            return ExtractionResult(title: nil, text: "", status: .failed, errorMessage: error.localizedDescription)
        }
    }

    private func extractTitle(from html: String) -> String? {
        guard let range = html.range(
            of: "<title[^>]*>(.*?)</title>",
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }

        let rawTitle = html[range]
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        let decoded = decodeHTMLEntities(String(rawTitle))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return decoded.isEmpty ? nil : decoded
    }

    private func extractReadableText(from html: String) -> String {
        let candidates = [
            firstMatch(in: html, pattern: "<article[^>]*>[\\s\\S]*?</article>"),
            firstMatch(in: html, pattern: "<main[^>]*>[\\s\\S]*?</main>"),
            firstMatch(in: html, pattern: "<body[^>]*>[\\s\\S]*?</body>")
        ]

        let htmlFragment = candidates.compactMap { $0 }.max(by: { $0.count < $1.count }) ?? html
        return cleanHTML(htmlFragment)
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let range = text.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }
        return String(text[range])
    }

    private func cleanHTML(_ html: String) -> String {
        var text = html
            .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<noscript[\\s\\S]*?</noscript>", with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "</p>", with: "\n\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "</h[1-6]>", with: "\n\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        text = decodeHTMLEntities(text)
            .replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\n[ \\t]+", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}
