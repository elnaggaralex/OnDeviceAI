import CoreAIImageSegmenter
import CoreAIKit
import CoreAIObjectDetector
import CoreAISpeech
import Foundation
import ImageIO

@available(iOS 27, *)
enum CoreAITaskProvider {
    static func readDocument(
        imageURL: URL,
        visionDirectoryURL: URL,
        decoderDirectoryURL: URL,
        assetsDirectoryURL: URL,
        tokenizerDirectoryURL: URL
    ) async throws -> String {
        let reader = try await KitDocReader(
            visionDir: visionDirectoryURL,
            decoderDir: decoderDirectoryURL,
            assetsDir: assetsDirectoryURL,
            tokenizerDir: tokenizerDirectoryURL
        )
        return try await reader.read(imageAt: imageURL)
    }

    static func transcribe(audioURL: URL, bundleURL: URL) async throws -> String {
        let model = try await SpeechRecognitionModel(resourcesAt: bundleURL)
        let (text, _) = try await model.transcribe(audioURL: audioURL)
        return text
    }

    static func transcribeParakeet(audioURL: URL, bundleURL: URL) async throws -> String {
        let model = try await KitParakeetModel(bundleAt: bundleURL)
        let samples = try AudioFile.pcm16kMono(audioURL)
        return try await model.transcribe(samples: samples).text
    }

    static func detectObjects(imageURL: URL, modelURL: URL) async throws -> String {
        let image = try loadImage(at: imageURL)
        let detector = try await ObjectDetector(resourcesAt: modelURL.path)
        let detections = try await detector.detect(image: image)
        guard !detections.isEmpty else { return "No objects detected." }
        return detections.prefix(10).map { detection in
            "\(detection.label) (\(Int(detection.confidence * 100))%)"
        }.joined(separator: "\n")
    }

    static func segmentImage(imageURL: URL, bundleURL: URL) async throws -> String {
        let image = try loadImage(at: imageURL)
        let segmenter = try await ImageSegmenter(resourcesAt: bundleURL.path)
        let response = try await segmenter.segment(image: image, pointQuery: PointQuery())
        return "Generated \(response.segments.count) object mask\(response.segments.count == 1 ? "" : "s")."
    }

    private static func loadImage(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CoreAITaskProviderError.invalidImage
        }
        return image
    }
}

private enum CoreAITaskProviderError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "The attached file could not be opened as an image."
    }
}
