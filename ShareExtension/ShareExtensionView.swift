import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?

    @Environment(\.modelContext) private var modelContext
    @State private var extractedText: String = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var sourceApp: String?
    @State private var sourceURLString: String?
    @State private var sourceTitle: String?
    @State private var attachmentFileName: String?
    @State private var extractionStatus: ExtractionStatus = .notNeeded
    @State private var contentType: CapturedContentType = .unknown
    @State private var captureMethod: CaptureMethod = .unknown
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { cancelAndDismiss() }

            // Bottom sheet
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    // Handle bar
                    Capsule()
                        .fill(.secondary.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)

                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(strings.shareSaveToApp)
                                .font(.headline)
                            Text(strings.shareWillCleanLater)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(strings.cancel) { cancelAndDismiss() }
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 20)

                    // Content preview
                    if isLoading {
                        ProgressView(strings.extractingContent)
                            .frame(height: 100)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                if let sourceTitle, !sourceTitle.isEmpty {
                                    Text(sourceTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                if let sourceURLString {
                                    Label(sourceURLString, systemImage: "link")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                if contentType == .image {
                                    Label(strings.imageSavedForOCR, systemImage: "photo")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(extractedText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 120)
                        .padding(.horizontal, 20)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                    }

                    // Usage info
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tint)
                        Text(strings.freeUsesRemaining(DailyUsageTracker.remainingFreeUses))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)

                    if let saveErrorMessage {
                        Label(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                    }

                    // Save button
                    Button {
                        Task { await saveAndDismiss() }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Text(isSaving ? strings.saving : strings.save)
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(extractedText.isEmpty || isSaving)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .task {
            await extractContent()
        }
    }

    // MARK: - Content Extraction

    private func extractContent() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            isLoading = false
            return
        }

        var payload = SharedContentPayload()

        for item in items {
            payload.merge(metadataFrom: item)
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(
                        forTypeIdentifier: UTType.plainText.identifier
                    ) as? String {
                        payload.merge(text: text)
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    if let item = try? await provider.loadItem(forTypeIdentifier: UTType.text.identifier) {
                        payload.merge(textItem: item)
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) {
                        payload.merge(urlItem: item)
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) {
                        await payload.merge(fileURLItem: item)
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    if let item = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier) {
                        await payload.merge(imageItem: item)
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                    if let item = try? await provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier) {
                        payload.merge(propertyListItem: item)
                    }
                }
            }
        }

        extractedText = payload.bestText
        sourceURLString = payload.urlString
        sourceTitle = payload.title
        attachmentFileName = payload.attachmentFileName
        extractionStatus = payload.extractionStatus
        contentType = payload.contentType
        captureMethod = payload.captureMethod
        isLoading = false
    }

    // MARK: - Actions

    private func saveAndDismiss() async {
        guard !extractedText.isEmpty else { return }
        isSaving = true
        saveErrorMessage = nil
        await Task.yield()

        let card = InsightCard(
            rawText: extractedText,
            sourceApp: sourceApp,
            sourceURLString: sourceURLString,
            sourceTitle: sourceTitle,
            attachmentFileName: attachmentFileName,
            extractionStatus: extractionStatus,
            contentType: contentType,
            captureMethod: captureMethod
        )
        modelContext.insert(card)

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(card)
            try? deleteSharedAttachment(fileName: attachmentFileName)
            attachmentFileName = nil
            saveErrorMessage = strings.shareSaveError
            isSaving = false
            return
        }

        isSaving = false
        dismiss()
    }

    private func cancelAndDismiss() {
        try? deleteSharedAttachment(fileName: attachmentFileName)
        attachmentFileName = nil
        dismiss()
    }

    private func dismiss() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

private struct SharedContentPayload {
    var text: String = ""
    var urlString: String?
    var title: String?
    var attachmentFileName: String?
    var contentType: CapturedContentType = .unknown
    var captureMethod: CaptureMethod = .unknown

    var bestText: String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            return trimmedText
        }
        if let title, let urlString {
            return "\(title)\n\(urlString)"
        }
        if attachmentFileName != nil {
            return AppStrings(rawPreferenceValue: OutputLanguagePreference.stored.rawValue).imageCapturedForOCR
        }
        return urlString ?? title ?? ""
    }

    var extractionStatus: ExtractionStatus {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.count >= 800 { return .fullText }
        if trimmedText.count >= 80 { return .partialText }
        if attachmentFileName != nil { return .pending }
        if urlString != nil { return .urlOnly }
        return trimmedText.isEmpty ? .failed : .partialText
    }

    mutating func merge(metadataFrom item: NSExtensionItem) {
        if title == nil {
            title = item.attributedTitle?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if text.isEmpty, let attributedContent = item.attributedContentText?.string {
            merge(text: attributedContent)
        }
    }

    mutating func merge(text newText: String) {
        let cleaned = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        if cleaned.count > text.count {
            text = cleaned
        }
        if contentType == .unknown {
            contentType = .text
        }
        if captureMethod == .unknown {
            captureMethod = .sharedText
        }
    }

    mutating func merge(textItem item: NSSecureCoding) {
        if let string = item as? String {
            merge(text: string)
        } else if let nsString = item as? NSString {
            merge(text: nsString as String)
        } else if let url = item as? URL {
            merge(urlItem: url as NSSecureCoding)
        } else if let nsURL = item as? NSURL {
            merge(urlItem: nsURL)
        } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
            merge(text: string)
        }
    }

    mutating func merge(urlItem item: NSSecureCoding) {
        if let url = item as? URL {
            urlString = url.absoluteString
        } else if let nsURL = item as? NSURL {
            urlString = nsURL.absoluteString
        } else if let string = item as? String {
            urlString = string
        } else if let nsString = item as? NSString {
            urlString = nsString as String
        }

        if urlString != nil, contentType == .unknown || contentType == .text {
            contentType = .url
        }
        if urlString != nil, captureMethod == .unknown || captureMethod == .sharedText {
            captureMethod = .sharedURL
        }
    }

    @MainActor
    mutating func merge(fileURLItem item: NSSecureCoding) async {
        if let url = item as? URL {
            await merge(fileURL: url)
        } else if let nsURL = item as? NSURL {
            await merge(fileURL: nsURL as URL)
        } else {
            merge(urlItem: item)
        }
    }

    @MainActor
    private mutating func merge(fileURL: URL) async {
        if fileURL.isFileURL {
            if title == nil {
                title = fileURL.deletingPathExtension().lastPathComponent
            }

            let string = await Task.detached(priority: .userInitiated) {
                guard let data = try? Data(contentsOf: fileURL) else { return nil as String? }
                return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode)
            }.value

            if let string {
                merge(text: string)
                contentType = .text
                captureMethod = .fileImport
                return
            }
        }

        urlString = fileURL.absoluteString
        if contentType == .unknown {
            contentType = .url
        }
        if captureMethod == .unknown {
            captureMethod = .fileImport
        }
    }

    @MainActor
    mutating func merge(imageItem item: NSSecureCoding) async {
        if let image = item as? UIImage {
            await store(image: image)
        } else if let url = item as? URL {
            await storeImage(from: url)
        } else if let nsURL = item as? NSURL {
            await storeImage(from: nsURL as URL)
        } else if let data = item as? Data {
            await storeImageData(data)
        }
    }

    @MainActor
    private mutating func storeImage(from url: URL) async {
        if url.isFileURL {
            let fileName = await Task.detached(priority: .userInitiated) {
                guard let data = try? Data(contentsOf: url) else { return nil as String? }
                return try? storeSharedAttachment(data: data, fileExtension: "jpg")
            }.value
            setImageAttachmentFileName(fileName)
        } else {
            urlString = url.absoluteString
        }
    }

    @MainActor
    private mutating func store(image: UIImage) async {
        if let data = image.jpegData(compressionQuality: 0.92) {
            await storeImageData(data)
        } else if let data = image.pngData() {
            await storeImageData(data, fileExtension: "png")
        }
    }

    @MainActor
    private mutating func storeImageData(_ data: Data, fileExtension: String = "jpg") async {
        let fileName = await Task.detached(priority: .userInitiated) {
            try? storeSharedAttachment(data: data, fileExtension: fileExtension)
        }.value
        setImageAttachmentFileName(fileName)
    }

    @MainActor
    private mutating func setImageAttachmentFileName(_ fileName: String?) {
        guard let fileName else { return }
        if let attachmentFileName, attachmentFileName != fileName {
            try? deleteSharedAttachment(fileName: attachmentFileName)
        }
        attachmentFileName = fileName
        contentType = .image
        captureMethod = .imageOCR
    }

    mutating func merge(propertyListItem item: NSSecureCoding) {
        let dictionary: [String: Any]?
        if let itemDictionary = item as? [String: Any] {
            dictionary = itemDictionary
        } else if let itemDictionary = item as? NSDictionary {
            dictionary = itemDictionary as? [String: Any]
        } else {
            dictionary = nil
        }

        guard let dictionary else {
            return
        }
        merge(propertyList: dictionary)
    }

    private mutating func merge(propertyList: [String: Any]) {
        if let title = firstString(in: propertyList, keys: ["title"]),
           self.title == nil {
            self.title = title
        }
        if let url = firstString(in: propertyList, keys: ["url", "URL"]) {
            urlString = url
        }
        if let body = firstString(in: propertyList, keys: ["body", "text", "selection"]) {
            merge(text: body)
        }
        contentType = .webPage
        captureMethod = .safariDOM

        if let preprocessing = propertyList[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any] {
            merge(propertyList: preprocessing)
        } else if let preprocessing = propertyList[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary as? [String: Any] {
            merge(propertyList: preprocessing)
        }
    }

    private func firstString(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }
}
