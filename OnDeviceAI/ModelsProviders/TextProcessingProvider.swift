import Foundation
import FoundationModels

@MainActor
final class TextProcessingProvider {
    private let session: LanguageModelSession

    init(session: LanguageModelSession = LanguageModelSession()) {
        self.session = session
    }

    func streamResponse(
        to prompt: String,
        imageURLs: [URL] = []
    ) -> LanguageModelSession.ResponseStream<String> {
        session.streamResponse {
            Prompt {
                prompt
                for imageURL in imageURLs {
                    Attachment(imageURL: imageURL)
                }
            }
        }
    }
}
