import Foundation
import FoundationModels

@Generable
enum RequestedSpeechStyle: Sendable {
    case natural
    case childlike
    case calm
    case energetic
}

@Generable
enum RequestedSpeechGender: Equatable, Sendable {
    case unspecified
    case female
    case male
}

struct SpeakTextTool: Tool {
    let speechSynthesisProvider: SpeechSynthesisProvider
    let name = "speakText"
    let description = "Speak text aloud using the requested vocal style and language. Use this when the user asks to read text aloud or generate speech audio."

    @Generable
    struct Arguments: Sendable {
        @Guide(description: "The words to speak. Preserve the user's supplied text exactly unless the user asked you to write or generate the words.")
        var text: String

        @Guide(description: "The requested delivery style. Use childlike for requests such as a child voice; this is approximated with an available system voice and adjusted pitch.")
        var style: RequestedSpeechStyle

        @Guide(description: "The requested speaker voice gender. Choose male or female when the user explicitly requests a man, male voice, woman, or female voice. Otherwise choose unspecified.")
        var gender: RequestedSpeechGender

        @Guide(description: "The BCP 47 language code matching the text, such as en-US. Use en-US when the user does not specify a language.")
        var languageCode: String
    }

    func call(arguments: Arguments) async throws -> String {
        let text = arguments.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return "Speech playback was not started because there was no text to speak."
        }

        let didStartPlayback = await speechSynthesisProvider.speakFromTool(
            text: text,
            style: arguments.style,
            gender: arguments.gender,
            languageCode: arguments.languageCode
        )
        if didStartPlayback {
            return "Speech playback started once. Do not call speakText again; finish the request with a brief confirmation."
        }
        return "Speech playback was already started for this request. Do not call speakText again; finish the request with a brief confirmation."
    }
}
