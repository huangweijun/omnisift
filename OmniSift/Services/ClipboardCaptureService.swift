import Foundation
import SwiftData
import UIKit

@MainActor
@Observable
final class ClipboardCaptureService {
    enum CandidateKind {
        case xiaohongshuURL
        case image
    }

    struct Candidate: Identifiable, Equatable {
        let id: String
        let kind: CandidateKind
        let title: String
        let message: String
        let preview: String?
        let changeCount: Int

        var canSuppressPermanently: Bool {
            kind == .xiaohongshuURL
        }
    }

    var candidate: Candidate?
    var errorMessage: String?

    private var modelContext: ModelContext?
    private var lastSeenChangeCount = -1
    private var savedCandidateIDs: Set<String> = []
    private var ignoredCandidateIDs: Set<String> = []
    private let strings = AppStrings(rawPreferenceValue: OutputLanguagePreference.stored.rawValue)

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func inspectPasteboardIfNeeded() async {
        guard modelContext != nil else { return }
        let pasteboard = UIPasteboard.general
        guard pasteboard.changeCount != lastSeenChangeCount else { return }

        lastSeenChangeCount = pasteboard.changeCount
        errorMessage = nil

        if let urlCandidate = await detectXiaohongshuURLCandidate(in: pasteboard) {
            candidate = urlCandidate
            return
        }

        if pasteboard.hasImages {
            let imageCandidateID = "image:\(pasteboard.changeCount)"
            guard !ignoredCandidateIDs.contains(imageCandidateID),
                  !savedCandidateIDs.contains(imageCandidateID) else {
                candidate = nil
                return
            }
            candidate = Candidate(
                id: imageCandidateID,
                kind: .image,
                title: strings.clipboardImageTitle,
                message: strings.clipboardImageMessage,
                preview: nil,
                changeCount: pasteboard.changeCount
            )
            return
        }

        candidate = nil
    }

    func collectCurrentCandidate() async {
        guard let candidate else { return }
        switch candidate.kind {
        case .xiaohongshuURL:
            await collectXiaohongshuURL(candidate)
        case .image:
            await collectImage(candidate)
        }
    }

    func ignoreCurrentCandidate(permanently: Bool = false) {
        guard let candidate else { return }
        ignoredCandidateIDs.insert(candidate.id)
        if permanently {
            persistSuppressedCandidateID(candidate.id)
        }
        self.candidate = nil
    }

    private func detectXiaohongshuURLCandidate(in pasteboard: UIPasteboard) async -> Candidate? {
        guard pasteboard.hasStrings || pasteboard.hasURLs else { return nil }

        let detectedURL = await detectedProbableURL(in: pasteboard)
        guard let url = detectedURL,
              isXiaohongshuURL(url) else {
            return nil
        }

        let id = candidateID(for: url)
        guard !ignoredCandidateIDs.contains(id),
              !savedCandidateIDs.contains(id),
              !isSuppressedCandidateID(id) else {
            return nil
        }

        return Candidate(
            id: id,
            kind: .xiaohongshuURL,
            title: strings.clipboardXiaohongshuTitle,
            message: strings.clipboardXiaohongshuMessage,
            preview: url.absoluteString,
            changeCount: pasteboard.changeCount
        )
    }

    private func detectedProbableURL(in pasteboard: UIPasteboard) async -> URL? {
        do {
            let values = try await pasteboard.detectedValues(for: [\.probableWebURL, \.links])
            if let linkURL = values.links.first?.url,
               SourceURLValidator.validatedWebURL(linkURL) != nil {
                return linkURL
            }
            if let url = URL(string: values.probableWebURL),
               SourceURLValidator.validatedWebURL(url) != nil {
                return url
            }
        } catch {
            return nil
        }

        return nil
    }

    private func collectXiaohongshuURL(_ candidate: Candidate) async {
        guard let modelContext else { return }
        let pasteboard = UIPasteboard.general
        guard pasteboard.changeCount == candidate.changeCount,
              let url = await readConfirmedURL(from: pasteboard) else {
            errorMessage = strings.clipboardSaveFailed
            self.candidate = nil
            return
        }

        let sourceText = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawText = sourceText?.isEmpty == false ? sourceText! : url.absoluteString
        let card = InsightCard(
            rawText: rawText,
            sourceApp: "小红书",
            sourceURLString: url.absoluteString,
            sourceTitle: strings.clipboardXiaohongshuTitle,
            extractionStatus: .urlOnly,
            contentType: .url,
            captureMethod: .clipboardURL
        )

        modelContext.insert(card)
        do {
            try modelContext.save()
            savedCandidateIDs.insert(candidate.id)
            self.candidate = nil
        } catch {
            modelContext.delete(card)
            errorMessage = strings.clipboardSaveFailed
        }
    }

    private func readConfirmedURL(from pasteboard: UIPasteboard) async -> URL? {
        if let url = pasteboard.url,
           SourceURLValidator.validatedWebURL(url) != nil {
            return url
        }

        if let detectedURL = await detectedProbableURL(in: pasteboard) {
            return detectedURL
        }

        guard let string = pasteboard.string else { return nil }
        return firstWebURL(in: string)
    }

    private func collectImage(_ candidate: Candidate) async {
        guard let modelContext else { return }
        let pasteboard = UIPasteboard.general
        guard pasteboard.changeCount == candidate.changeCount,
              let image = pasteboard.image,
              let imageData = image.jpegData(compressionQuality: 0.92) ?? image.pngData() else {
            errorMessage = strings.clipboardSaveFailed
            self.candidate = nil
            return
        }

        do {
            let fileName = try storeSharedAttachment(data: imageData, fileExtension: "jpg")
            let card = InsightCard(
                rawText: strings.imageCapturedForOCR,
                sourceApp: "Clipboard",
                attachmentFileName: fileName,
                extractionStatus: .pending,
                contentType: .image,
                captureMethod: .clipboardImage
            )
            modelContext.insert(card)
            try modelContext.save()
            savedCandidateIDs.insert(candidate.id)
            self.candidate = nil
        } catch {
            errorMessage = strings.clipboardSaveFailed
        }
    }

    private func isXiaohongshuURL(_ url: URL) -> Bool {
        guard let host = url.host(percentEncoded: false)?.lowercased() else { return false }
        return host == "xhslink.com" ||
            host.hasSuffix(".xhslink.com") ||
            host == "xiaohongshu.com" ||
            host.hasSuffix(".xiaohongshu.com")
    }

    private func firstWebURL(in text: String) -> URL? {
        SourceURLValidator.firstValidatedWebURL(in: text)
    }

    private func candidateID(for url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        let normalized = components?.url?.absoluteString ?? url.absoluteString
        return "url:\(normalized.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private func persistSuppressedCandidateID(_ id: String) {
        var suppressedIDs = Set(UserDefaults(suiteName: appGroupID)?.stringArray(forKey: Self.suppressedCandidateIDsKey) ?? [])
        suppressedIDs.insert(id)
        UserDefaults(suiteName: appGroupID)?.set(Array(suppressedIDs), forKey: Self.suppressedCandidateIDsKey)
    }

    private func isSuppressedCandidateID(_ id: String) -> Bool {
        let suppressedIDs = UserDefaults(suiteName: appGroupID)?.stringArray(forKey: Self.suppressedCandidateIDsKey) ?? []
        return suppressedIDs.contains(id)
    }

    private static let suppressedCandidateIDsKey = "clipboard_capture_suppressed_candidate_ids"
}
