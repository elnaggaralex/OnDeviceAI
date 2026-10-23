import Foundation
import FoundationModels

@Generable(description: "A structured result for a text understanding or transformation task.")
struct TextTaskResult {
    @Guide(description: "A concise title describing the result.")
    var title: String

    @Guide(description: "The main answer to the user's request. For a summary, provide a concise synthesis of the source text.")
    var response: String

    @Guide(description: "Up to five important facts that support or clarify the response. Use an empty list when none are useful.", .maximumCount(5))
    var keyPoints: [String]

    @Guide(description: "Concrete next steps requested or stated in the source. Use an empty list when not applicable.", .maximumCount(5))
    var actionItems: [String]
}

@MainActor
final class TextProcessingProvider {
    private let session: LanguageModelSession

    init(session: LanguageModelSession = LanguageModelSession()) {
        self.session = session
    }

    func streamResponse(
        to prompt: String,
        imageURLs: [URL] = []
    ) -> LanguageModelSession.ResponseStream<TextTaskResult> {
        session.streamResponse(generating: TextTaskResult.self) {
            Prompt {
                prompt
                for imageURL in imageURLs {
                    Attachment(imageURL: imageURL)
                }
            }
        }
    }
}
