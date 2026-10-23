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
        guard synthesizer.pauseSpeaking(at: .word) else { return }
        onPlaybackStateChange?(.paused)
    }

    func resume() {
        guard synthesizer.continueSpeaking() else { return }
        onPlaybackStateChange?(.speaking)
    }

    func stop() {
        let wasActive = activeUtterance != nil
        activeUtterance = nil
        if wasActive {
            synthesizer.stopSpeaking(at: .immediate)
        }
        onPlaybackStateChange?(.idle)
    }

    private func updatePlaybackState(_ state: SpeechPlaybackState, utteranceIdentifier: ObjectIdentifier) {
        guard let activeUtterance, ObjectIdentifier(activeUtterance) == utteranceIdentifier else { return }
        if state == .idle {
            self.activeUtterance = nil
        }
        onPlaybackStateChange?(state)
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
