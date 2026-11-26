import CoreAIKit
import Foundation
import FoundationModels
import ImageIO

@available(iOS 27, *)
struct GLMOCRProvider {
    func recognize(imageURL: URL, visionDirectoryURL: URL, decoderDirectoryURL: URL) async throws -> String {
        try validateCoreAIProducerMetadata(in: visionDirectoryURL)
        try validateCoreAIProducerMetadata(in: decoderDirectoryURL)

        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw GLMOCRProviderError.invalidImage
        }

        // GLM-OCR-CoreAI's exported graph is 22×31 merged tokens, not the
        // 32×24 geometry in CoreAIKit's stock GLM-OCR catalog preset.
        let architecture = VLArchitecture(
            vocab: 59_392,
            mergedTokens: 682,
            grid: 31,
            hidden: 1_536,
            patches: 2_728,
            patchDim: 1_176,
            deepstackPerToken: 0,
            imageSide: 616,
            patchSize: 14,
            temporalPatchSize: 2,
            imageWidth: 868,
            normalization: .clip,
            resize: .aspectFitPad,
            imStart: "",
            imEnd: "",
            userRole: "[gMASK]<sop><|user|>\n",
            assistantRole: "<|assistant|>",
            systemRole: "",
            roleSeparator: "",
            visionStart: "<|begin_of_image|>",
            visionEnd: "<|end_of_image|>",
            imagePad: "<|image|>",
            visionInput: .patches,
            visionOutput: "image_embeds",
            ropeShifted: true
        )
        let model = try await KitVisionModel(
            decoderBundleAt: decoderDirectoryURL,
            visionModelAt: visionDirectoryURL,
            arch: architecture,
            modelID: "glm-ocr-coreai-downloaded"
        )
        let session = LanguageModelSession(model: model)
        let response = try await session.respond(to: Prompt {
            Attachment(image)
            "Text Recognition:"
        })
        return response.content
    }

    private func validateCoreAIProducerMetadata(in bundleURL: URL) throws {
        let fileManager = FileManager.default
        let modelDirectories = (try? fileManager.contentsOfDirectory(
            at: bundleURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ))?.filter { $0.pathExtension.lowercased() == "aimodel" } ?? []
        let metadataURLs = [bundleURL.appendingPathComponent("metadata.json")]
            + modelDirectories.map { $0.appendingPathComponent("metadata.json") }
        let hasProducerMetadata = metadataURLs.contains { metadataURL in
            guard let data = try? Data(contentsOf: metadataURL),
                  let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let producer = metadata["producer"] as? String else { return false }
            return !producer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard hasProducerMetadata else {
            throw GLMOCRProviderError.incompatibleBundle
        }
    }
}

private enum GLMOCRProviderError: LocalizedError {
    case invalidImage
    case incompatibleBundle

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The attached file could not be opened as an image."
        case .incompatibleBundle:
            "This GLM-OCR bundle is missing Core AI producer metadata and may crash this OS's Core AI compiler. Update the downloaded model after its publisher re-exports it with compatible Core AI tooling."
        }
    }
}
