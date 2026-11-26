import Foundation
import UniformTypeIdentifiers

private enum GenerationRequest {
    case text(prompt: String, attachments: [URL], modelBundleURL: URL?)
    case image(prompt: String, modelDirectoryURL: URL)
    case imageToText(
        adapter: ImageToTextAdapter,
        imageURL: URL,
        modelDirectories: ImageToTextModelDirectories
    )
    case visionLanguage(
        adapter: VisionLanguageAdapter,
        imageURL: URL,
        prompt: String,
        modelDirectories: VisionLanguageModelDirectories
    )
    case speech(text: String, modelDirectoryURL: URL)
    case transcription(audioURL: URL, modelDirectoryURL: URL)
    case objectDetection(imageURL: URL, modelURL: URL)
    case imageSegmentation(imageURL: URL, modelDirectoryURL: URL)
}

extension HomeViewModel {
    private var isCoreAIImageGenerationModel: Bool {
        CoreAIImageGenerationProvider.supports(repositoryID: homeUI.uiModel.customModelName)
    }

    func toggleExecutionState() {
        if case .executing = homeUI.viewState {
            cancelGeneration()
            return
        }

        guard canRunAgent, let request = makeGenerationRequest() else { return }
        prepareForGeneration()
        startGeneration(request)
    }

    private func cancelGeneration() {
        activeGenerationID = nil
        generationTask?.cancel()
        generationTask = nil
        stopElapsedTimer()
        homeUI.viewState = .executed(homeUI.uiModel)
    }

    private func makeGenerationRequest() -> GenerationRequest? {
        let prompt = homeUI.uiModel.prompt
        let attachments = homeUI.uiModel.attachedFiles

        guard case let .CoreAI(repositoryID) = agentMode else {
            return .text(prompt: prompt, attachments: attachments, modelBundleURL: nil)
        }

        if isCoreAIImageGenerationModel {
            return makeImageGenerationRequest(repositoryID: repositoryID, prompt: prompt, attachments: attachments)
        }
        switch homeUI.uiModel.executionCapability {
        case let .visionLanguage(adapter):
            return makeVisionLanguageRequest(
                adapter: adapter,
                repositoryID: repositoryID,
                prompt: prompt,
                attachments: attachments
            )
        case let .imageToText(adapter):
            return makeImageToTextRequest(
                repositoryID: repositoryID,
                adapter: adapter,
                attachments: attachments
            )
        case .textToSpeech:
            guard requireDownloadedModel(repositoryID: repositoryID) else { return nil }
            return makeSpeechRequest(repositoryID: repositoryID, prompt: prompt, attachments: attachments)
        case .speechToText:
            return makeSpeechToTextRequest(repositoryID: repositoryID, attachments: attachments)
        case .objectDetection:
            return makeObjectDetectionRequest(repositoryID: repositoryID, attachments: attachments)
        case .imageSegmentation:
            return makeImageSegmentationRequest(repositoryID: repositoryID, attachments: attachments)
        case .textGeneration:
            guard requireDownloadedModel(repositoryID: repositoryID) else { return nil }
            return makeTextGenerationRequest(repositoryID: repositoryID, prompt: prompt, attachments: attachments)
        case .unsupported:
            failGeneration("The selected model does not have a compatible execution adapter in this app.")
            return nil
        }
    }

    private func makeImageGenerationRequest(
        repositoryID: String,
        prompt: String,
        attachments: [URL]
    ) -> GenerationRequest? {
        guard requireDownloadedModel(repositoryID: repositoryID) else { return nil }
        guard let directory = modelDownloadManager.flux2IOSModelDirectoryURL(repositoryID: repositoryID) else {
            failGeneration("The downloaded FLUX.2 repository is missing its iOS diffusion bundles or tokenizer. Download the model again, then retry.")
            return nil
        }
        guard attachments.isEmpty else {
            failGeneration("FLUX.2 currently accepts text prompts only. Remove attachments before generating an image.")
            return nil
        }
        return .image(prompt: prompt, modelDirectoryURL: directory)
    }

    private func makeImageToTextRequest(
        repositoryID: String,
        adapter: ImageToTextAdapter,
        attachments: [URL]
    ) -> GenerationRequest? {
        let imageURLs = attachments.filter { fileType(for: $0)?.conforms(to: .image) == true }
        let hasUnsupportedAttachments = attachments.contains {
            fileType(for: $0)?.conforms(to: .audio) == true
                || fileType(for: $0)?.conforms(to: .text) == true
        }
        guard attachments.count == 1, imageURLs.count == 1, !hasUnsupportedAttachments else {
            failGeneration("Image-to-text models need exactly one attached image. Remove any other attachments, then try again.")
            return nil
        }
        guard requireDownloadedModel(repositoryID: repositoryID) else { return nil }
        guard let directories = modelDownloadManager.imageToTextModelDirectories(repositoryID: repositoryID) else {
            failGeneration("The downloaded image-to-text model is missing compatible vision/decoder bundles or tokenizer assets. Download the model again, then retry.")
            return nil
        }
        return .imageToText(adapter: adapter, imageURL: imageURLs[0], modelDirectories: directories)
    }

    private func makeVisionLanguageRequest(
        adapter: VisionLanguageAdapter,
        repositoryID: String,
        prompt: String,
        attachments: [URL]
    ) -> GenerationRequest? {
        let imageURLs = attachments.filter { fileType(for: $0)?.conforms(to: .image) == true }
        let hasUnsupportedAttachments = attachments.contains {
            fileType(for: $0)?.conforms(to: .audio) == true
                || fileType(for: $0)?.conforms(to: .text) == true
        }
        guard attachments.count == 1, imageURLs.count == 1, !hasUnsupportedAttachments else {
            failGeneration("Vision-language models need exactly one attached image. Remove any other attachments, then try again.")
            return nil
        }
        guard requireDownloadedModel(repositoryID: repositoryID) else { return nil }
        guard let directories = modelDownloadManager.miniCPMV46ModelDirectories(repositoryID: repositoryID) else {
            failGeneration("The downloaded MiniCPM-V 4.6 model is missing its Core AI vision or decoder bundle. Download the model again, then retry.")
            return nil
        }
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return .visionLanguage(
            adapter: adapter,
            imageURL: imageURLs[0],
            prompt: trimmedPrompt.isEmpty ? "Describe this image." : trimmedPrompt,
            modelDirectories: directories
        )
    }

    private func makeSpeechRequest(
        repositoryID: String,
        prompt: String,
        attachments: [URL]
    ) -> GenerationRequest? {
        guard TextToSpeechProvider.supports(repositoryID: repositoryID) else {
            failGeneration("This app currently supports Audio8-TTS for custom text-to-speech models.")
            return nil
        }
        guard attachments.isEmpty else {
            failGeneration("Audio8-TTS currently accepts text only. Remove the attached files and enter the words to speak.")
            return nil
        }
        guard let directory = modelDownloadManager.audio8ModelDirectoryURL(repositoryID: repositoryID) else {
            failGeneration("The downloaded model is missing Audio8-TTS assets. It needs the DualAR model, codec decoder, and tokenizer.")
            return nil
        }
        return .speech(text: prompt, modelDirectoryURL: directory)
    }

    private func makeTextGenerationRequest(
        repositoryID: String,
        prompt: String,
        attachments: [URL]
    ) -> GenerationRequest? {
        guard homeUI.uiModel.customModelCategory == .text else {
            failGeneration("The selected model does not support a task available in this app. Choose a text-generation or supported text-to-speech model.")
            return nil
        }
        guard !attachments.contains(where: {
            fileType(for: $0)?.conforms(to: .image) == true
                || fileType(for: $0)?.conforms(to: .audio) == true
        }) else {
            failGeneration("This Core AI model supports text prompts and text files only. Remove the attached image or audio file, or switch to Apple Intelligence.")
            return nil
        }
        guard let bundleURL = modelDownloadManager.languageModelBundleURL(repositoryID: repositoryID) else {
            failGeneration("The downloaded repository is missing a Core AI language-model bundle (.aimodel, tokenizer, and metadata).")
            return nil
        }
        return .text(prompt: prompt, attachments: attachments, modelBundleURL: bundleURL)
    }

    private func makeSpeechToTextRequest(repositoryID: String, attachments: [URL]) -> GenerationRequest? {
        guard attachments.count == 1, let audioURL = attachments.first,
              fileType(for: audioURL)?.conforms(to: .audio) == true else {
            failGeneration("Speech recognition needs exactly one attached audio file.")
            return nil
        }
        guard requireDownloadedModel(repositoryID: repositoryID) else { return nil }
        guard let directory = modelDownloadManager.speechRecognitionBundleURL(repositoryID: repositoryID) else {
            failGeneration("The downloaded model is missing its Core AI speech-recognition bundle.")
            return nil
        }
        return .transcription(audioURL: audioURL, modelDirectoryURL: directory)
    }

    private func makeObjectDetectionRequest(repositoryID: String, attachments: [URL]) -> GenerationRequest? {
        guard attachments.count == 1, let imageURL = attachments.first,
              fileType(for: imageURL)?.conforms(to: .image) == true else {
            failGeneration("Object detection needs exactly one attached image.")
            return nil
        }
        guard requireDownloadedModel(repositoryID: repositoryID) else { return nil }
        guard let modelURL = modelDownloadManager.objectDetectionModelURL(repositoryID: repositoryID) else {
            failGeneration("The downloaded repository is missing its Core AI object-detection model.")
            return nil
        }
        return .objectDetection(imageURL: imageURL, modelURL: modelURL)
    }

    private func makeImageSegmentationRequest(repositoryID: String, attachments: [URL]) -> GenerationRequest? {
        guard attachments.count == 1, let imageURL = attachments.first,
              fileType(for: imageURL)?.conforms(to: .image) == true else {
            failGeneration("Image segmentation needs exactly one attached image.")
            return nil
        }
        guard requireDownloadedModel(repositoryID: repositoryID) else { return nil }
        guard let directory = modelDownloadManager.imageSegmentationBundleURL(repositoryID: repositoryID) else {
            failGeneration("The downloaded repository is missing its Core AI segmentation bundle.")
            return nil
        }
        return .imageSegmentation(imageURL: imageURL, modelDirectoryURL: directory)
    }

    private func requireDownloadedModel(repositoryID: String) -> Bool {
        guard !modelDownloadManager.isDownloaded(repositoryID: repositoryID) else { return true }
        isSelectedModelNotDownloadedAlertPresented = true
        return false
    }

    private func failGeneration(_ message: String) {
        homeUI.uiModel.errorMessage = message
        homeUI.viewState = .failed
    }

    private func prepareForGeneration() {
        homeUI.uiModel.structuredResponse = nil
        homeUI.uiModel.plainTextResponse = nil
        homeUI.uiModel.errorMessage = nil
        homeUI.uiModel.consumedTokenCount = nil
        homeUI.uiModel.isTokenCountEstimated = false
        homeUI.uiModel.speechText = nil
        homeUI.uiModel.speechStyle = nil
        homeUI.uiModel.speechGender = nil
        homeUI.uiModel.isGeneratedAudioReady = false
        homeUI.uiModel.speechPlaybackState = .idle
        homeUI.uiModel.generatedImageURL = nil
        homeUI.uiModel.imageGenerationRequest = nil
        homeUI.isImagePlaygroundPresented = false
        speechSynthesisProvider.stop()
        speechSynthesisProvider.prepareForNewRequest()
        imagePlaygroundProvider.prepareForNewRequest()
    }

    private func startGeneration(_ request: GenerationRequest) {
        let startTime = Date()
        let generationID = UUID()
        activeGenerationID = generationID
        elapsedTime = 0
        homeUI.viewState = .executing
        startElapsedTimer(from: startTime)
        setEstimatedInputTokens(for: request)

        generationTask = Task {
            await run(request, startedAt: startTime, generationID: generationID)
        }
    }

    private func setEstimatedInputTokens(for request: GenerationRequest) {
        let prompt = homeUI.uiModel.prompt
        switch request {
        case .imageToText:
            homeUI.uiModel.consumedTokenCount = 682 + max(1, (prompt.count + 3) / 4)
            homeUI.uiModel.isTokenCountEstimated = true
        case .visionLanguage:
            homeUI.uiModel.consumedTokenCount = 64 + max(1, (prompt.count + 3) / 4)
            homeUI.uiModel.isTokenCountEstimated = true
        case .speech:
            break
        case .transcription, .objectDetection, .imageSegmentation:
            break
        case .image, .text:
            homeUI.uiModel.consumedTokenCount = max(1, (prompt.count + 3) / 4)
            homeUI.uiModel.isTokenCountEstimated = true
        }
    }

    private func run(_ request: GenerationRequest, startedAt: Date, generationID: UUID) async {
        switch request {
        case let .image(prompt, directory):
            await generateCoreAIImage(
                prompt: prompt,
                modelDirectoryURL: directory,
                startedAt: startedAt,
                generationID: generationID
            )
        case let .imageToText(adapter, imageURL, directories):
            await generateOCR(
                adapter: adapter,
                imageURL: imageURL,
                modelDirectories: directories,
                startedAt: startedAt,
                generationID: generationID
            )
        case let .visionLanguage(adapter, imageURL, prompt, directories):
            await generateVisionLanguage(
                adapter: adapter,
                imageURL: imageURL,
                prompt: prompt,
                modelDirectories: directories,
                startedAt: startedAt,
                generationID: generationID
            )
        case let .speech(text, directory):
            await generateSpeech(
                text: text,
                modelDirectoryURL: directory,
                startedAt: startedAt,
                generationID: generationID
            )
        case let .transcription(audioURL, directory):
            await generateSpeechRecognition(audioURL: audioURL, modelDirectoryURL: directory, startedAt: startedAt, generationID: generationID)
        case let .objectDetection(imageURL, modelURL):
            await generateObjectDetection(imageURL: imageURL, modelURL: modelURL, startedAt: startedAt, generationID: generationID)
        case let .imageSegmentation(imageURL, directory):
            await generateImageSegmentation(imageURL: imageURL, modelDirectoryURL: directory, startedAt: startedAt, generationID: generationID)
        case let .text(prompt, attachments, bundleURL):
            await generateText(
                prompt: prompt,
                attachedFiles: attachments,
                modelBundleURL: bundleURL,
                startedAt: startedAt,
                generationID: generationID
            )
        }
    }
}
