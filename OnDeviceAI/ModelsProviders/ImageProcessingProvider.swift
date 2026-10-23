import FoundationModels
import Vision

private struct IdentifyImageObjectsTool: Tool {
    let name = "identifyImageObjects"
    let description = "Use Vision to classify the objects and visual categories in an attached image when the user asks what objects are present or asks to identify an item."

    @SessionProperty(\.history) var history

    @Generable
    struct Arguments {
        @Guide(description: "The attached image to inspect for object identification.")
        var image: ImageReference
    }

    func call(arguments: Arguments) async throws -> String {
        guard let image = arguments.image.resolved(in: history) else {
            return "I couldn't access the image selected for object identification."
        }

        let observations = try await ClassifyImageRequest().perform(on: image.ciImage)
        let classifications = observations
            .filter { $0.confidence >= 0.05 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(8)

        guard !classifications.isEmpty else {
            return "Vision did not find any likely object or scene categories in this image."
        }

        return classifications
            .map { "\($0.identifier) (\(Int($0.confidence * 100))% confidence)" }
            .joined(separator: ", ")
    }
}

@MainActor
final class ImageProcessingProvider {
    private let session: LanguageModelSession

    init() {
        #if targetEnvironment(simulator)
        let tools: [any Tool] = [IdentifyImageObjectsTool()]
        #else
        let tools: [any Tool] = [OCRTool(), IdentifyImageObjectsTool()]
        #endif

        session = LanguageModelSession(
            tools: tools
        ) {
            """
            Help with tasks involving the user's attached images. Follow the user's prompt to decide what analysis is needed.
            For requests to read, transcribe, or extract visible text, use OCRTool when available; otherwise inspect the image for visible text directly.
            For requests to identify objects or list what is present, use identifyImageObjects for each relevant image and explain its labels in context.
            For broader visual questions, inspect the attached images directly. Do not claim OCR or Vision classification results unless the corresponding tool returned them.
            """
        }
    }

    func streamResponse(
        to prompt: String,
        imageURLs: [URL]
    ) -> LanguageModelSession.ResponseStream<TextTaskResult> {
        session.streamResponse(generating: TextTaskResult.self) {
            Prompt {
                prompt
                for (index, imageURL) in imageURLs.enumerated() {
                    "Attached image \(index + 1): \(imageURL.lastPathComponent)"
                    Attachment(imageURL: imageURL)
                        .label("image-\(index + 1)")
                }
            }
        }
    }
}
