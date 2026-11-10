import CoreAIDiffusionPipeline
import Foundation
import ImageIO

@MainActor
final class CoreAIImageGenerationProvider {
    static let repositoryID = "grabbou/FLUX.2-klein-4B-CoreAI"

    static func supports(repositoryID: String) -> Bool {
        repositoryID.caseInsensitiveCompare(Self.repositoryID) == .orderedSame
    }

    func generate(prompt: String, modelDirectoryURL: URL) async throws -> URL {
        let pipeline = try await Flux2Pipeline(from: modelDirectoryURL, mode: .half)
        do {
            let configuration = PipelineConfiguration(
                prompt: prompt,
                seed: UInt32.random(in: UInt32.min...UInt32.max),
                stepCount: 4,
                guidanceScale: 1.0,
                schedulerType: .discreteFlow,
                decodeResolution: .half,
                lazyModelLoading: true
            )
            let result = try await pipeline.generateImages(configuration: configuration) { _ in
                !Task.isCancelled
            }
            try Task.checkCancellation()
            guard let image = result.images.first else {
                throw CoreAIImageGenerationError.emptyResult
            }

            let outputDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("GeneratedImages", isDirectory: true)
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let outputURL = outputDirectory.appendingPathComponent("\(UUID().uuidString).png")
            guard let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                "public.png" as CFString,
                1,
                nil
            ) else {
                throw CoreAIImageGenerationError.couldNotSaveImage
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw CoreAIImageGenerationError.couldNotSaveImage
            }
            await pipeline.unloadResources()
            return outputURL
        } catch {
            await pipeline.unloadResources()
            throw error
        }
    }
}

private enum CoreAIImageGenerationError: LocalizedError {
    case emptyResult
    case couldNotSaveImage

    var errorDescription: String? {
        switch self {
        case .emptyResult:
            "FLUX.2 completed without returning an image."
        case .couldNotSaveImage:
            "The generated image could not be saved."
        }
    }
}
