import Foundation
import ImageIO
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

            let text = try recognizeText(
                in: cgImage,
                orientation: image.imageOrientation.cgImagePropertyOrientation
            )

            guard !text.isEmpty else {
                throw OCRError.noRecognizedText
            }

            let status: ExtractionStatus = text.count >= 500 ? .fullText : .partialText
            return OCRResult(text: text, status: status, errorMessage: nil)
        } catch {
            return OCRResult(text: "", status: .failed, errorMessage: error.localizedDescription)
        }
    }

    private func recognizeText(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> String {
        var bestText = ""
        var lastError: Error?

        for attempt in recognitionAttempts {
            do {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = attempt.level
                request.usesLanguageCorrection = attempt.usesLanguageCorrection
                request.automaticallyDetectsLanguage = true

                let languages = supportedRecognitionLanguages(
                    preferred: attempt.languages,
                    request: request
                )
                if !languages.isEmpty {
                    request.recognitionLanguages = languages
                }

                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: orientation,
                    options: [:]
                )
                try handler.perform([request])

                let text = recognizedText(from: request)
                if text.count > bestText.count {
                    bestText = text
                }
                if !text.isEmpty {
                    return text
                }
            } catch {
                lastError = error
            }
        }

        if !bestText.isEmpty {
            return bestText
        }
        if let lastError {
            throw lastError
        }
        throw OCRError.noRecognizedText
    }

    private func recognizedText(from request: VNRecognizeTextRequest) -> String {
        (request.results ?? [])
            .compactMap { observation in
                observation.topCandidates(3)
                    .first { !$0.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
                    .string
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func supportedRecognitionLanguages(
        preferred: [String],
        request: VNRecognizeTextRequest
    ) -> [String] {
        guard !preferred.isEmpty,
              let supported = try? request.supportedRecognitionLanguages() else {
            return preferred
        }

        let supportedSet = Set(supported)
        return preferred.filter { supportedSet.contains($0) }
    }

    private var recognitionAttempts: [RecognitionAttempt] {
        [
            RecognitionAttempt(
                level: .accurate,
                languages: ["zh-Hans", "zh-Hant", "en-US"],
                usesLanguageCorrection: true
            ),
            RecognitionAttempt(
                level: .accurate,
                languages: [],
                usesLanguageCorrection: true
            ),
            RecognitionAttempt(
                level: .fast,
                languages: ["zh-Hans", "zh-Hant", "en-US"],
                usesLanguageCorrection: false
            )
        ]
    }
}

private struct RecognitionAttempt {
    let level: VNRequestTextRecognitionLevel
    let languages: [String]
    let usesLanguageCorrection: Bool
}

private extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .left:
            return .left
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}
