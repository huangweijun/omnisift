import Foundation
import WebKit

/// Loads shared URLs in a headless in-app browser and extracts rendered DOM text.
/// Used when plain HTTP fetching cannot read dynamic or script-rendered pages.
@MainActor
final class BrowserContentExtractionService: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var loadContinuation: CheckedContinuation<Void, Error>?

    func extract(from url: URL, timeout: TimeInterval = 20) async -> WebContentExtractionService.ExtractionResult {
        guard let url = SourceURLValidator.validatedWebURL(url) else {
            return WebContentExtractionService.ExtractionResult(
                title: nil,
                text: "",
                status: .failed,
                errorMessage: "Only http and https links can be extracted"
            )
        }

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844),
            configuration: configuration
        )
        webView.customUserAgent =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        webView.navigationDelegate = self
        self.webView = webView

        defer {
            self.webView = nil
            self.loadContinuation = nil
        }

        do {
            try await loadPage(in: webView, url: url, timeout: timeout)

            // 智能等待：轮询直到内容稳定或超时（最多 5 秒）
            var lastLength = 0
            for _ in 0..<10 {
                try await Task.sleep(for: .milliseconds(500))
                let currentLength = (try? await webView.evaluateJavaScript("document.body.innerText.length")) as? Int ?? 0
                if currentLength > 500, currentLength == lastLength {
                    break
                }
                lastLength = currentLength
            }

            let payload = try await webView.evaluateJavaScript(Self.readabilityScript)
            let parsed = Self.parseJavaScriptPayload(payload)

            guard !parsed.text.isEmpty else {
                throw BrowserExtractionError.emptyContent
            }

            let status: ExtractionStatus = parsed.text.count >= 500 ? .fullText : .partialText
            return WebContentExtractionService.ExtractionResult(
                title: parsed.title,
                text: parsed.text,
                status: status,
                errorMessage: nil
            )
        } catch {
            return WebContentExtractionService.ExtractionResult(
                title: nil,
                text: "",
                status: .failed,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func loadPage(in webView: WKWebView, url: URL, timeout: TimeInterval) async throws {
        let timeoutTask = Task { @MainActor in
            try await Task.sleep(for: .seconds(timeout))
            resumeLoadIfNeeded(error: BrowserExtractionError.timedOut)
        }
        defer { timeoutTask.cancel() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loadContinuation = continuation
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url,
              SourceURLValidator.validatedWebURL(url) != nil else {
            resumeLoadIfNeeded(error: BrowserExtractionError.privateNetworkURL)
            return
        }
        resumeLoadIfNeeded()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        resumeLoadIfNeeded(error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        resumeLoadIfNeeded(error: error)
    }

    private func resumeLoadIfNeeded(error: Error? = nil) {
        guard let loadContinuation else { return }
        self.loadContinuation = nil

        if let error {
            loadContinuation.resume(throwing: error)
        } else {
            loadContinuation.resume()
        }
    }

    private static let readabilityScript = """
    (function() {
        function clean(text) {
            return (text || "")
                .replace(/\\n{3,}/g, "\\n\\n")
                .replace(/[ \\t]{2,}/g, " ")
                .trim();
        }

        var heading = document.querySelector("h1");
        var title = clean((heading && heading.innerText) || document.title || "");

        var article = document.querySelector("article");
        var main = document.querySelector("main");
        var source = article || main || document.body;
        if (!source) {
            return { title: title, body: "" };
        }

        var body = clean(source.innerText);
        if (title && body.indexOf(title) === 0) {
            body = clean(body.slice(title.length));
        }

        return { title: title, body: body };
    })();
    """

    private static func parseJavaScriptPayload(_ payload: Any?) -> (title: String?, text: String) {
        if let dictionary = payload as? [String: Any] {
            let title = (dictionary["title"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let body = (dictionary["body"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (title?.isEmpty == false ? title : nil, body)
        }

        if let dictionary = payload as? NSDictionary,
           let title = dictionary["title"] as? String,
           let body = dictionary["body"] as? String {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmedTitle.isEmpty ? nil : trimmedTitle, trimmedBody)
        }

        return (nil, "")
    }

    private enum BrowserExtractionError: LocalizedError {
        case timedOut
        case emptyContent
        case privateNetworkURL

        var errorDescription: String? {
            switch self {
            case .timedOut:
                "The in-app browser timed out while loading the page"
            case .emptyContent:
                "The in-app browser loaded the page but found no readable text"
            case .privateNetworkURL:
                "Private or local network links cannot be extracted"
            }
        }
    }
}
