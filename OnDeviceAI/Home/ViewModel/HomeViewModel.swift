import Foundation
import Observation
import FoundationModels

@MainActor
@Observable
final class HomeViewModel {
    private var homeUI = HomeUI()
    var isAppleIntelligenceEnableAlertPresented = false
    private(set) var agentMode: AgentMode = .AppleIntelligence
    private(set) var elapsedTime: TimeInterval = 0

    var viewState: ViewState { homeUI.viewState }
    var uiModel: UIModel { homeUI.uiModel }
    
    private let textProcessingProvider = TextProcessingProvider()
    private var generationTask: Task<Void, Never>?
    private var elapsedTimerTask: Task<Void, Never>?
    private var activeGenerationID: UUID?

    func checkAppleIntelligenceAvailability() {
        if case .unavailable(.appleIntelligenceNotEnabled) = SystemLanguageModel.default.availability {
            isAppleIntelligenceEnableAlertPresented = true
        }
    }
    
    var isModelPickerPresented: Bool {
        get { homeUI.isModelPickerPresented }
        set { homeUI.isModelPickerPresented = newValue }
    }

    func updatePrompt(_ prompt: String) {
        homeUI.uiModel.prompt = prompt
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

    func selectCustomModel(_ modelName: String) {
        homeUI.uiModel.customModelName = modelName
        if homeUI.uiModel.selectedMode != 0 {
            homeUI.uiModel.modelName = modelName
            agentMode = .CoreAI(model: modelName)
            refreshExecutedStateIfNeeded()
        }
        homeUI.isModelPickerPresented = false
    }

    func toggleExecutionState() {
        switch homeUI.viewState {
        case .executing:
            activeGenerationID = nil
            generationTask?.cancel()
            generationTask = nil
            stopElapsedTimer()
            homeUI.viewState = .executed(homeUI.uiModel)
        case .executed, .failed:
            guard !homeUI.uiModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            guard case .AppleIntelligence = agentMode else {
                homeUI.viewState = .failed
                return
            }
            homeUI.uiModel.responseText = ""
            let startTime = Date()
            let generationID = UUID()
            activeGenerationID = generationID
            elapsedTime = 0
            homeUI.viewState = .executing
            startElapsedTimer(from: startTime)
            generationTask = Task { await generateText(startedAt: startTime, generationID: generationID) }
        }
    }

    func failExecution() {
        homeUI.viewState = .failed
    }

    private func refreshExecutedStateIfNeeded() {
        if case .executed = homeUI.viewState {
            homeUI.viewState = .executed(homeUI.uiModel)
        }
    }

    private func generateText(startedAt startTime: Date, generationID: UUID) async {
        defer {
            if activeGenerationID == generationID {
                activeGenerationID = nil
                stopElapsedTimer()
                generationTask = nil
            }
        }
        do {
            for try await snapshot in textProcessingProvider.streamResponse(to: homeUI.uiModel.prompt) {
                try Task.checkCancellation()
                guard activeGenerationID == generationID else { return }
                homeUI.uiModel.responseText = snapshot.content
            }

            guard activeGenerationID == generationID else { return }
            homeUI.uiModel.completionDuration = String(format: "%.1fs", Date().timeIntervalSince(startTime))
            homeUI.viewState = .executed(homeUI.uiModel)
        } catch is CancellationError {
            if activeGenerationID == generationID {
                homeUI.viewState = .executed(homeUI.uiModel)
            }
        } catch {
            if activeGenerationID == generationID {
                homeUI.viewState = .failed
            }
        }
    }

    private func startElapsedTimer(from startTime: Date) {
        elapsedTimerTask = Task {
            while !Task.isCancelled {
                elapsedTime = Date().timeIntervalSince(startTime)
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    break
                }
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimerTask?.cancel()
        elapsedTimerTask = nil
    }
}

enum ViewState {
    case executing
    case executed(UIModel)
    case failed
}

struct UIModel {
    var prompt = ""
    var selectedMode = 0
    var modelName = "Apple Intelligence"
    var customModelName = "GPT-4o"
    var completionDuration = "0s"
    var responseText = ""
}

private extension HomeViewModel {
    struct HomeUI {
        var viewState: ViewState
        var uiModel: UIModel
        var isModelPickerPresented = false

        init() {
            let model = UIModel()
            uiModel = model
            viewState = .executed(model)
        }
    }
}
