#if DEBUG
import AVFAudio
import CoreGraphics
import Foundation
import FoundationModels
import ImageIO
import UIKit

@MainActor
enum CoreAIModelPilot {
    private static let repositories = [
        "coreai-community/LFM2.5-1.2B-CoreAI",
        "coreai-community/MiniCPM5-1B-CoreAI",
        "coreai-community/Unlimited-OCR-CoreAI",
        "coreai-community/Audio8-TTS-Preview-0.6b-CoreAI",
        "coreai-community/Parakeet-TDT-0.6B-CoreAI",
        "coreai-community/RF-DETR-CoreAI",
        "grabbou/EfficientSAM-Ti-CoreAI",
        "grabbou/FLUX.2-klein-4B-CoreAI"
    ]
    private static let glmOCRRepository = "mlboydaisuke/GLM-OCR-CoreAI"

    private static var imageURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("coreai-pilot-input.png")
    }

    private static var audioURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("coreai-pilot-audio.wav")
    }

    static func run(using viewModel: HomeViewModel) async {
        guard #available(iOS 27, *) else {
            print("PILOT ABORT unsupported iOS version")
            Darwin.exit(2)
        }

        print("PILOT BEGIN device=\(UIDevice.current.model) os=\(UIDevice.current.systemVersion)")

        var results: [(String, Bool, String)] = []

        do {
            try makeImageFixture()
        } catch {
            print("PILOT ABORT fixture error: \(error.localizedDescription)")
            Darwin.exit(2)
        }

        if ProcessInfo.processInfo.arguments.contains("--coreai-model-pilot-rfdetr") {
            await runModel(repositories[5], using: viewModel) {
                guard let modelURL = viewModel.modelDownloadManager.objectDetectionModelURL(repositoryID: repositories[5]) else {
                    throw PilotError.missingModelAssets
                }
                return try await CoreAITaskProvider.detectObjects(imageURL: imageURL, modelURL: modelURL)
            }.append(to: &results)
            print("PILOT SUMMARY \(results.filter(\.1).count)/\(results.count) passed")
            for (repositoryID, didPass, detail) in results {
                print("PILOT RESULT \(didPass ? "PASS" : "FAIL") \(repositoryID) — \(detail)")
            }
            print("PILOT END")
            Darwin.exit(results.allSatisfy(\.1) ? 0 : 1)
        }

        if ProcessInfo.processInfo.arguments.contains("--coreai-model-pilot-glm-ocr") {
            await runModel(glmOCRRepository, using: viewModel) {
                guard let directories = viewModel.modelDownloadManager.imageToTextModelDirectories(
                    repositoryID: glmOCRRepository
                ) else {
                    throw PilotError.missingModelAssets
                }
                return try await GLMOCRProvider().recognize(
                    imageURL: imageURL,
                    visionDirectoryURL: directories.vision,
                    decoderDirectoryURL: directories.decoder
                )
            }.append(to: &results)
            print("PILOT SUMMARY \(results.filter(\.1).count)/\(results.count) passed")
            for (repositoryID, didPass, detail) in results {
                print("PILOT RESULT \(didPass ? "PASS" : "FAIL") \(repositoryID) — \(detail)")
            }
            print("PILOT END")
            Darwin.exit(results.allSatisfy(\.1) ? 0 : 1)
        }

        await runModel(repositories[0], using: viewModel) {
            try await runLanguageModel(repositoryID: repositories[0], viewModel: viewModel)
        }.append(to: &results)

        await runModel(repositories[1], using: viewModel) {
            try await runLanguageModel(repositoryID: repositories[1], viewModel: viewModel)
        }.append(to: &results)

        var synthesizedSpeech: [Float] = []
        await runModel(repositories[3], using: viewModel) {
            guard let directory = viewModel.modelDownloadManager.audio8ModelDirectoryURL(repositoryID: repositories[3]) else {
                throw PilotError.missingModelAssets
            }
            synthesizedSpeech = try await viewModel.textToSpeechProvider.synthesize(
                text: "This is a Core AI speech test.",
                modelDirectoryURL: directory
            )
            guard !synthesizedSpeech.isEmpty else { throw PilotError.emptyOutput }
            try writeAudio(synthesizedSpeech, to: audioURL)
            return "Generated \(synthesizedSpeech.count) audio samples."
        }.append(to: &results)

        await runModel(repositories[4], using: viewModel) {
            guard !synthesizedSpeech.isEmpty,
                  let directory = viewModel.modelDownloadManager.speechRecognitionBundleURL(repositoryID: repositories[4]) else {
                throw PilotError.missingModelAssets
            }
            return try await CoreAITaskProvider.transcribeParakeet(audioURL: audioURL, bundleURL: directory)
        }.append(to: &results)

        await runModel(repositories[5], using: viewModel) {
            guard let modelURL = viewModel.modelDownloadManager.objectDetectionModelURL(repositoryID: repositories[5]) else {
                throw PilotError.missingModelAssets
            }
            return try await CoreAITaskProvider.detectObjects(imageURL: imageURL, modelURL: modelURL)
        }.append(to: &results)

        await runModel(repositories[6], using: viewModel) {
            guard let directory = viewModel.modelDownloadManager.imageSegmentationBundleURL(repositoryID: repositories[6]) else {
                throw PilotError.missingModelAssets
            }
            return try await CoreAITaskProvider.segmentImage(imageURL: imageURL, bundleURL: directory)
        }.append(to: &results)

        await runModel(repositories[7], using: viewModel) {
            guard let directory = viewModel.modelDownloadManager.flux2IOSModelDirectoryURL(repositoryID: repositories[7]) else {
                throw PilotError.missingModelAssets
            }
            let outputURL = try await viewModel.coreAIImageGenerationProvider.generate(
                prompt: "A minimal studio photograph of a red apple on a white table",
                modelDirectoryURL: directory
            )
            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            return "Generated image file (\(attributes[.size] ?? 0) bytes)."
        }.append(to: &results)

        // Keep OCR last because the Core AI iOS vision compiler currently aborts
        // on the Unlimited-OCR vision graph instead of returning a Swift error.
        await runModel(repositories[2], using: viewModel) {
            guard let directories = viewModel.modelDownloadManager.imageToTextModelDirectories(repositoryID: repositories[2]),
                  let assets = directories.assets, let tokenizer = directories.tokenizer else {
                throw PilotError.missingModelAssets
            }
            return try await CoreAITaskProvider.readDocument(
                imageURL: imageURL,
                visionDirectoryURL: directories.vision,
                decoderDirectoryURL: directories.decoder,
                assetsDirectoryURL: assets,
                tokenizerDirectoryURL: tokenizer
            )
        }.append(to: &results)

        let passed = results.filter(\.1).count
        print("PILOT SUMMARY \(passed)/\(results.count) passed")
        for (repositoryID, didPass, detail) in results {
            print("PILOT RESULT \(didPass ? "PASS" : "FAIL") \(repositoryID) — \(detail)")
        }
        print("PILOT END")
        Darwin.exit(passed == results.count ? 0 : 1)
    }

    private static func runModel(
        _ repositoryID: String,
        using viewModel: HomeViewModel,
        operation: () async throws -> String
    ) async -> PilotResult {
        let displayName = repositoryID.split(separator: "/").last.map(String.init) ?? repositoryID
        let start = Date()
        print("PILOT MODEL START \(repositoryID)")
        do {
            try await viewModel.modelDownloadManager.downloadForPilot(
                repositoryID: repositoryID,
                displayName: displayName
            )
            let output = try await operation()
            let detail = "\(String(format: "%.1f", Date().timeIntervalSince(start)))s; \(output.prefix(220))"
            print("PILOT MODEL PASS \(repositoryID) — \(detail)")
            return PilotResult(repositoryID: repositoryID, passed: true, detail: detail)
        } catch {
            let detail = error.localizedDescription
            print("PILOT MODEL FAIL \(repositoryID) — \(detail)")
            return PilotResult(repositoryID: repositoryID, passed: false, detail: detail)
        }
    }

    private static func runLanguageModel(repositoryID: String, viewModel: HomeViewModel) async throws -> String {
        guard let bundleURL = viewModel.modelDownloadManager.languageModelBundleURL(repositoryID: repositoryID) else {
            throw PilotError.missingModelAssets
        }
        defer { viewModel.textProcessingProvider.finishCustomModelRun() }
        let stream = try await viewModel.textProcessingProvider.streamResponse(
            to: "Reply with a short greeting and name the model task you can perform.",
            languageModelBundleURL: bundleURL
        )
        var response = ""
        for try await snapshot in stream {
            response = snapshot.content.response ?? response
        }
        guard !response.isEmpty else { throw PilotError.emptyOutput }
        return response
    }

    private static func makeImageFixture() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
            UIColor.systemGreen.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 312, y: 160, width: 400, height: 400))
            UIColor.black.setStroke()
            context.cgContext.setLineWidth(12)
            context.cgContext.stroke(CGRect(x: 80, y: 690, width: 864, height: 180))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 74),
                .foregroundColor: UIColor.black
            ]
            ("CORE AI TEST").draw(at: CGPoint(x: 140, y: 740), withAttributes: attributes)
        }
        guard let cgImage = image.cgImage,
              let destination = CGImageDestinationCreateWithURL(imageURL as CFURL, "public.png" as CFString, 1, nil) else {
            throw PilotError.fixtureCreationFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { throw PilotError.fixtureCreationFailed }
    }

    private static func writeAudio(_ samples: [Float], to url: URL) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { source in
            guard let sourceAddress = source.baseAddress, let destination = buffer.floatChannelData?[0] else { return }
            destination.update(from: sourceAddress, count: samples.count)
        }
        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try audioFile.write(from: buffer)
    }
}

private struct PilotResult {
    let repositoryID: String
    let passed: Bool
    let detail: String

    var tuple: (String, Bool, String) { (repositoryID, passed, detail) }
}

private extension PilotResult {
    func append(to results: inout [(String, Bool, String)]) {
        results.append(tuple)
    }
}

private enum PilotError: LocalizedError {
    case emptyOutput
    case missingModelAssets
    case fixtureCreationFailed

    var errorDescription: String? {
        switch self {
        case .emptyOutput: "The model returned no output."
        case .missingModelAssets: "The downloaded model is missing an asset required by its runner."
        case .fixtureCreationFailed: "The smoke-test image could not be created."
        }
    }
}
#endif
