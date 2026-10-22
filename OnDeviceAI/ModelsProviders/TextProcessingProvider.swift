import FoundationModels

@MainActor
final class TextProcessingProvider {
    private let session: LanguageModelSession

    init(session: LanguageModelSession = LanguageModelSession()) {
        self.session = session
    }

    func streamResponse(to prompt: String) -> LanguageModelSession.ResponseStream<String> {
        session.streamResponse(to: prompt)
    }
}
