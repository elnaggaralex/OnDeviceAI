import AVFAudio
import Foundation
import FoundationModels
import Speech

struct AudioFileReference: Sendable {
    let id: String
    let fileName: String
    let url: URL
}

struct TranscribeAudioTool: Tool {
    let audioFiles: [AudioFileReference]
    let name = "transcribeAudio"

    var description: String {
        let availableIDs = audioFiles.map(\.id).joined(separator: ", ")
        return "Transcribe speech from attached audio. Available audio IDs: \(availableIDs). Use only these IDs."
    }

    @Generable
    struct Arguments {
        @Guide(description: "IDs of the attached audio files to transcribe, such as audio-1. Include all relevant audio IDs in one call.")
        var audioIDs: [String]
    }

    func call(arguments: Arguments) async throws -> String {
        guard !arguments.audioIDs.isEmpty else {
            return "No audio IDs were provided."
        }

        var transcripts: [String] = []
        var processedIDs = Set<String>()
        for audioID in arguments.audioIDs where processedIDs.insert(audioID).inserted {
            guard let audioFile = audioFiles.first(where: { $0.id == audioID }) else {
                transcripts.append("No attached audio file matches ID \(audioID).")
                continue
            }

            do {
                let transcript = try await AudioTranscriptionProvider().transcribe(audioURL: audioFile.url)
                let content = transcript.isEmpty ? "No recognizable speech was found." : transcript
                transcripts.append("--- \(audioFile.fileName) ---\n\(content)")
            } catch {
                transcripts.append("--- \(audioFile.fileName) ---\nTranscription failed: \(error.localizedDescription)")
            }
        }
        return transcripts.joined(separator: "\n\n")
    }
}

struct AudioTranscriptionProvider {
    func transcribe(audioURL: URL) async throws -> String {
        guard SpeechTranscriber.isAvailable else {
            throw AudioTranscriptionError.transcriptionUnavailable
        }

        let englishLocale = Locale(identifier: "en-US")
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: englishLocale) else {
            throw AudioTranscriptionError.unsupportedLocale
        }

        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await installationRequest.downloadAndInstall()
        }

        let audioFile = try AVAudioFile(forReading: audioURL)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let transcriptionTask = Task {
            var transcript = ""
            for try await result in transcriber.results where result.isFinal {
                transcript += String(result.text.characters)
            }
            return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        do {
            if let lastSampleTime = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSampleTime)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            return try await transcriptionTask.value
        } catch {
            transcriptionTask.cancel()
            await analyzer.cancelAndFinishNow()
            throw error
        }
    }
}

private enum AudioTranscriptionError: LocalizedError {
    case transcriptionUnavailable
    case unsupportedLocale

    var errorDescription: String? {
        switch self {
        case .transcriptionUnavailable:
            return "Speech transcription isn’t available on this device or simulator."
        case .unsupportedLocale:
            return "English speech transcription isn’t supported by this device or simulator."
        }
    }
}
