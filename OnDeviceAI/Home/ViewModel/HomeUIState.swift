import Foundation
import FoundationModels

enum ViewState {
    case executing
    case executed(UIModel)
    case failed
}

struct UIModel {
    var prompt = ""
    var attachedFiles: [URL] = []
    var selectedMode = 0
    var modelName = "Apple Intelligence"
    var customModelName = "coreai-community/LFM2.5-1.2B-CoreAI"
    var customModelCategory: AIModelCategory = .text
    var customModelTask = "Text Generation"
    var executionCapability: AIModelExecutionCapability {
        AIModelExecutionCapability(task: customModelTask, repositoryID: customModelName)
    }
    var completionDuration = "0s"
    var consumedTokenCount: Int?
    var isTokenCountEstimated = false
    var errorMessage: String?
    var structuredResponse: TextTaskResult.PartiallyGenerated?
    var plainTextResponse: String?
    var speechText: String?
    var isGeneratedAudioReady = false
    var speechStyle: RequestedSpeechStyle?
    var speechGender: RequestedSpeechGender?
    var speechLanguageCode = "en-US"
    var speechPlaybackState: SpeechPlaybackState = .idle
    var imageGenerationRequest: ImageGenerationRequest?
    var generatedImageURL: URL?
}

struct HomeUIState {
    var viewState: ViewState
    var uiModel: UIModel
    var isModelPickerPresented = false
    var isImagePlaygroundPresented = false
    var isAppleIntelligenceEnableAlertPresented = false
    var isSelectedModelNotDownloadedAlertPresented = false

    init() {
        let model = UIModel()
        uiModel = model
        viewState = .executed(model)
    }
}
