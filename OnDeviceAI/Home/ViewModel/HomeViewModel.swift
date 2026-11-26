import Foundation
import Observation
import FoundationModels
import UniformTypeIdentifiers

@MainActor
@Observable
final class HomeViewModel {
    var homeUI = HomeUIState()
    var isAppleIntelligenceEnableAlertPresented: Bool {
        get { homeUI.isAppleIntelligenceEnableAlertPresented }
        set { homeUI.isAppleIntelligenceEnableAlertPresented = newValue }
    }
    var isSelectedModelNotDownloadedAlertPresented: Bool {
        get { homeUI.isSelectedModelNotDownloadedAlertPresented }
        set { homeUI.isSelectedModelNotDownloadedAlertPresented = newValue }
    }
    var agentMode: AgentMode = .AppleIntelligence
    var elapsedTime: TimeInterval = 0

    var viewState: ViewState { homeUI.viewState }
    var uiModel: UIModel { homeUI.uiModel }
    var canRunAgent: Bool {
        !homeUI.uiModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || homeUI.uiModel.attachedFiles.contains {
                let type = UTType(filenameExtension: $0.pathExtension)
                return type?.conforms(to: .text) == true
                    || type?.conforms(to: .image) == true
                    || type?.conforms(to: .audio) == true
            }
    }
    let textProcessingProvider: TextProcessingProvider
    let textToSpeechProvider = TextToSpeechProvider()
    let coreAIImageGenerationProvider = CoreAIImageGenerationProvider()
    let speechSynthesisProvider: SpeechSynthesisProvider
    let imagePlaygroundProvider: ImagePlaygroundProvider
    let modelDownloadManager = ModelDownloadManager()
    var generationTask: Task<Void, Never>?
    var elapsedTimerTask: Task<Void, Never>?
    var activeGenerationID: UUID?

    init() {
        let speechProvider = SpeechSynthesisProvider()
        let imageProvider = ImagePlaygroundProvider()
        speechSynthesisProvider = speechProvider
        imagePlaygroundProvider = imageProvider
        textProcessingProvider = TextProcessingProvider(
            speechSynthesisProvider: speechProvider,
            imagePlaygroundProvider: imageProvider
        )
        speechProvider.onPlaybackStateChange = { [weak self] state in
            self?.homeUI.uiModel.speechPlaybackState = state
        }
        speechProvider.onSpeechRequest = { [weak self] text, style, gender, languageCode in
            self?.homeUI.uiModel.speechText = text
            self?.homeUI.uiModel.speechStyle = style
            self?.homeUI.uiModel.speechGender = gender
            self?.homeUI.uiModel.speechLanguageCode = languageCode
        }
        imageProvider.onGenerationRequest = { [weak self] request in
            guard let self else { return }
            self.homeUI.uiModel.imageGenerationRequest = request
            self.homeUI.uiModel.generatedImageURL = nil
            self.homeUI.isImagePlaygroundPresented = true
        }
    }

    func checkAppleIntelligenceAvailability() {
        if case .unavailable(.appleIntelligenceNotEnabled) = SystemLanguageModel.default.availability {
            isAppleIntelligenceEnableAlertPresented = true
        }
    }
    
    var isModelPickerPresented: Bool {
        get { homeUI.isModelPickerPresented }
        set { homeUI.isModelPickerPresented = newValue }
    }

    var isImagePlaygroundPresented: Bool {
        get { homeUI.isImagePlaygroundPresented }
        set { homeUI.isImagePlaygroundPresented = newValue }
    }

    var imageGenerationRequest: ImageGenerationRequest? {
        homeUI.uiModel.imageGenerationRequest
    }

    func didCreateImage(at url: URL) {
        homeUI.uiModel.generatedImageURL = url
        homeUI.isImagePlaygroundPresented = false
        refreshExecutedStateIfNeeded()
    }

    func cancelledImageGeneration() {
        homeUI.uiModel.imageGenerationRequest = nil
        homeUI.isImagePlaygroundPresented = false
    }

    func updatePrompt(_ prompt: String) {
        homeUI.uiModel.prompt = prompt
        refreshExecutedStateIfNeeded()
    }

    func updateAttachedFiles(_ urls: [URL]) {
        homeUI.uiModel.attachedFiles = urls
        refreshExecutedStateIfNeeded()
    }

    func selectMode(_ mode: Int) {
        homeUI.uiModel.selectedMode = mode
        homeUI.uiModel.modelName = mode == 0 ? "Apple Intelligence" : homeUI.uiModel.customModelName
        agentMode = mode == 0
            ? .AppleIntelligence
            : .CoreAI(model: homeUI.uiModel.customModelName)
        refreshExecutedStateIfNeeded()
    }

    func selectCustomModel(
        _ modelName: String,
        category: AIModelCategory = .text,
        task: String = "Text Generation"
    ) {
        homeUI.uiModel.customModelName = modelName
        homeUI.uiModel.customModelCategory = category
        homeUI.uiModel.customModelTask = task
        if homeUI.uiModel.selectedMode != 0 {
            homeUI.uiModel.modelName = modelName
            agentMode = .CoreAI(model: modelName)
            refreshExecutedStateIfNeeded()
        }
        homeUI.isModelPickerPresented = false
    }

    func downloadSelectedModel() {
        guard case let .CoreAI(repositoryID) = agentMode else { return }
        let displayName = repositoryID.split(separator: "/").last.map(String.init) ?? repositoryID
        modelDownloadManager.startDownload(repositoryID: repositoryID, displayName: displayName)
    }

    func failExecution() {
        homeUI.viewState = .failed
    }

    func toggleSpeechPlayback() {
        switch homeUI.uiModel.speechPlaybackState {
        case .speaking:
            speechSynthesisProvider.pause()
        case .paused:
            speechSynthesisProvider.resume()
        case .idle:
            if homeUI.uiModel.isGeneratedAudioReady {
                speechSynthesisProvider.playGeneratedAudio()
                return
            }
            guard let speechText = homeUI.uiModel.speechText,
                  let speechStyle = homeUI.uiModel.speechStyle,
                  !speechText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            speechSynthesisProvider.speak(
                text: speechText,
                style: speechStyle,
                gender: homeUI.uiModel.speechGender ?? .unspecified,
                languageCode: homeUI.uiModel.speechLanguageCode
            )
        }
    }

    func stopSpeechPlayback() {
        speechSynthesisProvider.stop()
    }

    func refreshExecutedStateIfNeeded() {
        if case .executed = homeUI.viewState {
            homeUI.viewState = .executed(homeUI.uiModel)
        }
    }

}
