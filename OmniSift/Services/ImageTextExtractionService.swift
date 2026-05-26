import Foundation
import Vision
import UIKit

actor ImageTextExtractionService {
    struct OCRResult: Sendable {
        let text: String
        let status: ExtractionStatus
        let errorMessage: String?
    }

    enum OCRError: LocalizedError {
        case missingAttachment
        case unreadableImage
        case noRecognizedText

        var errorDescription: String? {
            switch self {
            case .missingAttachment:
                "Could not find the shared image attachment."
            case .unreadableImage:
                "The shared image could not be read."
            case .noRecognizedText:
                "No readable text was found in the image."
            }
        }
    }

    func extractText(fromAttachmentNamed fileName: String) async -> OCRResult {
        do {
            guard let url = sharedAttachmentURL(fileName: fileName) else {
                throw OCRError.missingAttachment
            }

            let data = try Data(contentsOf: url)
            guard let image = UIImage(data: data), let cgImage = image.cgImage else {
                throw OCRError.unreadableImage
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try handler.perform([request])

            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else {
                throw OCRError.noRecognizedText
            }

            let status: ExtractionStatus = text.count >= 500 ? .fullText : .partialText
            return OCRResult(text: text, status: status, errorMessage: nil)
        } catch {
            return OCRResult(text: "", status: .failed, errorMessage: error.localizedDescription)
        }
    }
}
