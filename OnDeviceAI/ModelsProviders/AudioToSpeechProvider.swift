import CoreAIKit
import Foundation

@MainActor
final class AudioToSpeechProvider {
    static let sampleRate = 44_100

    static func supports(repositoryID: String) -> Bool {
        repositoryID.caseInsensitiveCompare("coreai-community/Audio8-TTS-Preview-0.6b-CoreAI") == .orderedSame
    }

    func synthesize(text: String, modelDirectoryURL: URL) async throws -> [Float] {
        let paths = Audio8Paths.standard(root: modelDirectoryURL)
        let model = try await Audio8TTS(paths: paths)
        return try await model.synthesize(text)
    }
}
