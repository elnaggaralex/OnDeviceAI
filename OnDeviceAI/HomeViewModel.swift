import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    struct HomeUI {
        enum ViewState {
            case executing
            case executed(UIModel)
            case failed
        }

        struct UIModel {
            var prompt = "Analyze recent quarterly growth metrics for clean energy startups and synthesize an executive summary infographic."
            var selectedMode = 0
            var modelName = "Apple Intelligence"
            var customModelName = "GPT-4o"
            var completionDuration = "1.4s"
            var responseImageName = "GeneratedInfographic"
        }

        var viewState: ViewState
        var uiModel: UIModel
        var isModelPickerPresented = false

        init() {
            let model = UIModel()
            uiModel = model
            viewState = .executed(model)
        }
    }

    var homeUI = HomeUI()

    func updatePrompt(_ prompt: String) {
        homeUI.uiModel.prompt = prompt
        refreshExecutedStateIfNeeded()
    }

    func selectMode(_ mode: Int) {
        homeUI.uiModel.selectedMode = mode
        homeUI.uiModel.modelName = mode == 0 ? "Apple Intelligence" : homeUI.uiModel.customModelName
        refreshExecutedStateIfNeeded()
    }

    func selectCustomModel(_ modelName: String) {
        homeUI.uiModel.customModelName = modelName
        if homeUI.uiModel.selectedMode != 0 {
            homeUI.uiModel.modelName = modelName
            refreshExecutedStateIfNeeded()
        }
        homeUI.isModelPickerPresented = false
    }

    func toggleExecutionState() {
        switch homeUI.viewState {
        case .executing:
            homeUI.viewState = .executed(homeUI.uiModel)
        case .executed, .failed:
            homeUI.viewState = .executing
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
}
