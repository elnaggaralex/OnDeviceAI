import AVFAudio
import Foundation

enum SpeechPlaybackState: Equatable, Sendable {
    case idle
    case speaking
    case paused
}

@MainActor
final class SpeechSynthesisProvider: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var activeUtterance: AVSpeechUtterance?
    private var generatedAudioPlayer: AVAudioPlayer?
    private var generatedAudioData: Data?
    private var didHandleSpeechToolRequest = false
    var onPlaybackStateChange: ((SpeechPlaybackState) -> Void)?
    var onSpeechRequest: ((String, RequestedSpeechStyle, RequestedSpeechGender, String) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(
        text: String,
        style: RequestedSpeechStyle,
        gender: RequestedSpeechGender = .unspecified,
        languageCode: String
    ) {
        stop()
        onSpeechRequest?(text, style, gender, languageCode)

        let utterance = AVSpeechUtterance(string: text)
        utterance.postUtteranceDelay = 0.25
        let normalizedLanguageCode = languageCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedLanguage = normalizedLanguageCode.isEmpty ? "en-US" : normalizedLanguageCode
        utterance.voice = voice(for: requestedLanguage, gender: gender)

        switch style {
        case .natural:
            break
        case .childlike:
            // AVSpeechSynthesisVoice has no age selector; this approximates a childlike delivery.
            utterance.pitchMultiplier = 1.2
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        case .calm:
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
            utterance.pitchMultiplier = 0.95
        case .energetic:
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.08
            utterance.pitchMultiplier = 1.08
        }

        activeUtterance = utterance
        synthesizer.speak(utterance)
        onPlaybackStateChange?(.speaking)
    }

    func prepareForNewRequest() {
        didHandleSpeechToolRequest = false
        generatedAudioPlayer?.stop()
        generatedAudioPlayer = nil
        generatedAudioData = nil
    }

    func loadGeneratedAudio(samples: [Float], sampleRate: Int) throws {
        stop()
        let data = Self.wavData(samples: samples, sampleRate: sampleRate)
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        guard player.prepareToPlay() else {
            throw GeneratedAudioPlaybackError.couldNotPrepare
        }
        generatedAudioData = data
        generatedAudioPlayer = player
    }

    func playGeneratedAudio() {
        guard let generatedAudioPlayer else { return }
        generatedAudioPlayer.currentTime = 0
        generatedAudioPlayer.play()
        onPlaybackStateChange?(.speaking)
    }

    func speakFromTool(
        text: String,
        style: RequestedSpeechStyle,
        gender: RequestedSpeechGender,
        languageCode: String
    ) -> Bool {
        guard !didHandleSpeechToolRequest else { return false }
        didHandleSpeechToolRequest = true
        speak(text: text, style: style, gender: gender, languageCode: languageCode)
        return true
    }

    private func voice(for languageCode: String, gender: RequestedSpeechGender) -> AVSpeechSynthesisVoice? {
        guard gender != .unspecified else {
            return AVSpeechSynthesisVoice(language: languageCode)
                ?? AVSpeechSynthesisVoice(language: "en-US")
        }

        let requestedGender: AVSpeechSynthesisVoiceGender = gender == .male ? .male : .female
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let exactLanguageVoices = voices.filter {
            $0.language.caseInsensitiveCompare(languageCode) == .orderedSame
        }
        let baseLanguage = languageCode.split(separator: "-").first.map(String.init) ?? languageCode
        let sameLanguageVoices = exactLanguageVoices.isEmpty
            ? voices.filter {
                $0.language.split(separator: "-").first?.caseInsensitiveCompare(baseLanguage) == .orderedSame
            }
            : exactLanguageVoices

        return sameLanguageVoices.first { $0.gender == requestedGender }
            ?? voices.first {
                $0.language.caseInsensitiveCompare("en-US") == .orderedSame && $0.gender == requestedGender
            }
            ?? AVSpeechSynthesisVoice(language: languageCode)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    func pause() {
        if let generatedAudioPlayer {
            generatedAudioPlayer.pause()
            onPlaybackStateChange?(.paused)
            return
        }
        guard synthesizer.pauseSpeaking(at: .word) else { return }
        onPlaybackStateChange?(.paused)
    }

    func resume() {
        if let generatedAudioPlayer {
            generatedAudioPlayer.play()
            onPlaybackStateChange?(.speaking)
            return
        }
        guard synthesizer.continueSpeaking() else { return }
        onPlaybackStateChange?(.speaking)
    }

    func stop() {
        let wasActive = activeUtterance != nil
        activeUtterance = nil
        if wasActive {
            synthesizer.stopSpeaking(at: .immediate)
        }
        generatedAudioPlayer?.stop()
        generatedAudioPlayer?.currentTime = 0
        onPlaybackStateChange?(.idle)
    }

    private func updateGeneratedPlaybackState(
        _ state: SpeechPlaybackState,
        playerIdentifier: ObjectIdentifier
    ) {
        guard let generatedAudioPlayer,
              ObjectIdentifier(generatedAudioPlayer) == playerIdentifier else { return }
        onPlaybackStateChange?(state)
    }

    private static func wavData(samples: [Float], sampleRate: Int) -> Data {
        var pcmData = Data(capacity: samples.count * MemoryLayout<Int16>.size)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            let pcmSample = Int16((clamped * Float(Int16.max)).rounded())
            pcmData.appendLittleEndian(pcmSample)
        }

        var wav = Data()
        wav.append(contentsOf: [82, 73, 70, 70]) // RIFF
        wav.appendLittleEndian(UInt32(36 + pcmData.count))
        wav.append(contentsOf: [87, 65, 86, 69, 102, 109, 116, 32]) // WAVE fmt
        wav.appendLittleEndian(UInt32(16))
        wav.appendLittleEndian(UInt16(1))
        wav.appendLittleEndian(UInt16(1))
        wav.appendLittleEndian(UInt32(sampleRate))
        wav.appendLittleEndian(UInt32(sampleRate * MemoryLayout<Int16>.size))
        wav.appendLittleEndian(UInt16(MemoryLayout<Int16>.size))
        wav.appendLittleEndian(UInt16(16))
        wav.append(contentsOf: [100, 97, 116, 97]) // data
        wav.appendLittleEndian(UInt32(pcmData.count))
        wav.append(pcmData)
        return wav
    }

    private func updatePlaybackState(_ state: SpeechPlaybackState, utteranceIdentifier: ObjectIdentifier) {
        guard let activeUtterance, ObjectIdentifier(activeUtterance) == utteranceIdentifier else { return }
        if state == .idle {
            self.activeUtterance = nil
        }
        onPlaybackStateChange?(state)
    }
}

extension SpeechSynthesisProvider: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let playerIdentifier = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            self?.updateGeneratedPlaybackState(.idle, playerIdentifier: playerIdentifier)
        }
    }
}

private enum GeneratedAudioPlaybackError: LocalizedError {
    case couldNotPrepare

    var errorDescription: String? {
        "The generated audio could not be prepared for playback."
    }
}

private extension Data {
    mutating func appendLittleEndian<Value: FixedWidthInteger>(_ value: Value) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { append(contentsOf: $0) }
    }
}

extension SpeechSynthesisProvider: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let utteranceIdentifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.updatePlaybackState(.speaking, utteranceIdentifier: utteranceIdentifier)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        let utteranceIdentifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.updatePlaybackState(.paused, utteranceIdentifier: utteranceIdentifier)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        let utteranceIdentifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.updatePlaybackState(.speaking, utteranceIdentifier: utteranceIdentifier)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let utteranceIdentifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.updatePlaybackState(.idle, utteranceIdentifier: utteranceIdentifier)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let utteranceIdentifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            self?.updatePlaybackState(.idle, utteranceIdentifier: utteranceIdentifier)
        }
    }
}
