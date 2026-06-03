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
            ShareConstellationBackdrop()
                .ignoresSafeArea()
                .onTapGesture { cancelAndDismiss() }

            VStack(spacing: 0) {
                Spacer()
                capturePanel
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await extractContent()
        }
    }

    private var capturePanel: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(.white.opacity(0.22))
                .frame(width: 42, height: 5)
                .padding(.top, 10)

            header
                .padding(.horizontal, 20)

            contentPreview
                .padding(.horizontal, 20)

            usageRow
                .padding(.horizontal, 20)

            if let saveErrorMessage {
                Label(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.44, blue: 0.36))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }

            saveButton
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.06, blue: 0.10).opacity(0.98),
                            Color(red: 0.02, green: 0.16, blue: 0.18).opacity(0.96),
                            Color(red: 0.10, green: 0.08, blue: 0.05).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.22),
                            Color(red: 0.21, green: 0.82, blue: 0.74).opacity(0.30),
                            Color(red: 1.0, green: 0.75, blue: 0.28).opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.42), radius: 28, x: 0, y: -10)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.74, blue: 0.66),
                                Color(red: 0.97, green: 0.69, blue: 0.24)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "sparkles")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(strings.shareSaveToApp)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(strings.shareWillCleanLater)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                cancelAndDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.10), in: Circle())
            }
            .accessibilityLabel(strings.cancel)
        }
    }

    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: previewIconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.40, green: 0.78, blue: 1.0))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(strings.shareIncomingSignal)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))
                    Text(previewStatusText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()
                ShareStatusPill(text: statusText)
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text(strings.extractingContent)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, minHeight: 102, alignment: .center)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if let sourceTitle = clean(sourceTitle) {
                            Text(sourceTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }

                        if let sourceURLString = clean(sourceURLString) {
                            Label {
                                Text(sourceURLString)
                                    .lineLimit(2)
                            } icon: {
                                Image(systemName: "link")
                            }
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.52))
                        }

                        if contentType == .image {
                            Label(strings.imageSavedForOCR, systemImage: "photo")
                                .font(.caption)
                                .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.30))
                        }

                        Text(previewText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 138)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.065))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var usageRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.97, green: 0.70, blue: 0.24))
            Text(strings.freeUsesRemaining(DailyUsageTracker.remainingFreeUses))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
        }
    }

    private var saveButton: some View {
        Button {
            Task { await saveAndDismiss() }
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                }
                Text(isSaving ? strings.saving : strings.save)
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(saveButtonBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(canSave ? 0.18 : 0.04), lineWidth: 1)
            }
        }
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.48)
    }

    private var saveButtonBackground: some ShapeStyle {
        LinearGradient(
            colors: canSave
            ? [Color(red: 0.12, green: 0.66, blue: 0.60), Color(red: 0.14, green: 0.38, blue: 0.72)]
            : [Color.white.opacity(0.12), Color.white.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var canSave: Bool {
        !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving && !isLoading
    }

    private var previewText: String {
        let text = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return strings.shareNoReadablePreview }
        return text
    }

    private var previewIconName: String {
        switch contentType {
        case .image: "photo.on.rectangle.angled"
        case .url: "link.circle.fill"
        case .webPage: "globe.asia.australia.fill"
        case .text: "text.quote"
        case .unknown: "sparkles"
        }
    }

    private var previewStatusText: String {
        if isLoading { return strings.extractingStatus }
        return strings.shareReadyToLight
    }

    private var statusText: String {
        switch extractionStatus {
        case .notNeeded: strings.capture
        case .pending: strings.extractingStatus
        case .fullText: strings.fullTextStatus
        case .partialText: strings.partialTextStatus
        case .urlOnly: strings.urlOnlyStatus
        case .failed: strings.extractFailedStatus
        }
    }

    private func clean(_ value: String?) -> String? {
        let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cleaned, !cleaned.isEmpty else { return nil }
        return cleaned
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

private struct ShareConstellationBackdrop: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.58)

            LinearGradient(
                colors: [
                    Color(red: 0.00, green: 0.03, blue: 0.07).opacity(0.96),
                    Color(red: 0.03, green: 0.17, blue: 0.20).opacity(0.78),
                    Color.black.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ShareStarField()
                .opacity(0.78)
                .blur(radius: 0.2)
        }
    }
}

private struct ShareStarField: View {
    private let stars: [ShareStar] = [
        ShareStar(x: 0.13, y: 0.16, size: 2.2, opacity: 0.72),
        ShareStar(x: 0.24, y: 0.10, size: 1.2, opacity: 0.40),
        ShareStar(x: 0.39, y: 0.19, size: 1.8, opacity: 0.55),
        ShareStar(x: 0.62, y: 0.12, size: 2.4, opacity: 0.66),
        ShareStar(x: 0.78, y: 0.21, size: 1.4, opacity: 0.45),
        ShareStar(x: 0.86, y: 0.09, size: 2.0, opacity: 0.52),
        ShareStar(x: 0.17, y: 0.32, size: 1.5, opacity: 0.40),
        ShareStar(x: 0.34, y: 0.38, size: 2.7, opacity: 0.78),
        ShareStar(x: 0.55, y: 0.31, size: 1.3, opacity: 0.38),
        ShareStar(x: 0.73, y: 0.42, size: 1.9, opacity: 0.54),
        ShareStar(x: 0.91, y: 0.35, size: 1.1, opacity: 0.36),
        ShareStar(x: 0.09, y: 0.52, size: 1.7, opacity: 0.50),
        ShareStar(x: 0.28, y: 0.58, size: 1.2, opacity: 0.38),
        ShareStar(x: 0.47, y: 0.50, size: 2.0, opacity: 0.62),
        ShareStar(x: 0.68, y: 0.60, size: 1.4, opacity: 0.42),
        ShareStar(x: 0.84, y: 0.54, size: 2.5, opacity: 0.70)
    ]

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let points = stars.map { star in
                    CGPoint(x: size.width * star.x, y: size.height * star.y)
                }

                var route = Path()
                for (index, point) in points.prefix(8).enumerated() {
                    if index == 0 {
                        route.move(to: point)
                    } else {
                        route.addLine(to: point)
                    }
                }
                context.stroke(
                    route,
                    with: .color(Color(red: 0.30, green: 0.86, blue: 0.76).opacity(0.18)),
                    lineWidth: 1
                )

                for star in stars {
                    let rect = CGRect(
                        x: size.width * star.x - star.size / 2,
                        y: size.height * star.y - star.size / 2,
                        width: star.size,
                        height: star.size
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(star.opacity))
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct ShareStar {
    let x: Double
    let y: Double
    let size: Double
    let opacity: Double
}

private struct ShareStatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color(red: 0.80, green: 0.96, blue: 0.92))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color(red: 0.12, green: 0.64, blue: 0.58).opacity(0.22), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color(red: 0.48, green: 0.95, blue: 0.85).opacity(0.22), lineWidth: 1)
            }
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
        if urlString == nil,
           let detectedURL = SourceURLValidator.firstValidatedWebURL(in: cleaned) {
            urlString = detectedURL.absoluteString
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

    private mutating func setURLString(_ candidate: String?) {
        guard let candidate,
              let url = SourceURLValidator.firstValidatedWebURL(in: candidate) else {
            return
        }
        urlString = url.absoluteString
    }

    mutating func merge(urlItem item: NSSecureCoding) {
        if let url = item as? URL {
            setURLString(url.absoluteString)
        } else if let nsURL = item as? NSURL {
            setURLString(nsURL.absoluteString)
        } else if let string = item as? String {
            setURLString(string)
        } else if let nsString = item as? NSString {
            setURLString(nsString as String)
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

        setURLString(fileURL.absoluteString)
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
            setURLString(url.absoluteString)
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
            setURLString(url)
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
