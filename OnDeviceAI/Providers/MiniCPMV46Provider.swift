import CoreAIKit
import Foundation
import FoundationModels
import ImageIO

@available(iOS 27, *)
struct MiniCPMV46Provider {
    func respond(
        imageURL: URL,
        prompt: String,
        modelDirectories: VisionLanguageModelDirectories
    ) async throws -> String {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MiniCPMV46ProviderError.invalidImage
        }

        let model = try await KitVisionModel(
            decoderBundleAt: modelDirectories.decoder,
            visionModelAt: modelDirectories.vision,
            arch: .miniCPMV46,
            modelID: "minicpm-v-4.6-coreai-downloaded"
        )
        let session = LanguageModelSession(model: model)
        let response = try await session.respond(to: Prompt {
            Attachment(image)
            prompt
        })
        return response.content
    }
}

private enum MiniCPMV46ProviderError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "The attached file could not be opened as an image."
    }
}
