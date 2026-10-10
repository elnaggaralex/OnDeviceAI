import SwiftUI

struct ContentView: View {
    @State private var viewModel = HomeViewModel()

    private var promptBinding: Binding<String> {
        Binding(
            get: { viewModel.homeUI.uiModel.prompt },
            set: { viewModel.updatePrompt($0) }
        )
    }

    private var modeBinding: Binding<Int> {
        Binding(
            get: { viewModel.homeUI.uiModel.selectedMode },
            set: { viewModel.selectMode($0) }
        )
    }

    private var modelPickerBinding: Binding<Bool> {
        Binding(
            get: { viewModel.homeUI.isModelPickerPresented },
            set: { viewModel.homeUI.isModelPickerPresented = $0 }
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                AgentHeaderView()

                VStack(spacing: 16) {
                    AgentModePicker(selection: modeBinding)
                    ModelCardView(
                        selectedMode: viewModel.homeUI.uiModel.selectedMode,
                        modelName: viewModel.homeUI.uiModel.customModelName
                    ) {
                        viewModel.homeUI.isModelPickerPresented = true
                    }
                    PromptCardView(prompt: promptBinding)
                    RunAgentButton(isRunning: isExecuting) {
                        viewModel.toggleExecutionState()
                    }
                    CompletedResultCard(
                        viewState: viewModel.homeUI.viewState,
                        model: viewModel.homeUI.uiModel
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(AppColors.page.ignoresSafeArea())
        .preferredColorScheme(.light)
        .confirmationDialog("Choose a model", isPresented: modelPickerBinding, titleVisibility: .visible) {
            Button("Claude 3.5 Sonnet") { viewModel.selectCustomModel("Claude 3.5 Sonnet") }
            Button("GPT-4o") { viewModel.selectCustomModel("GPT-4o") }
            Button("Gemini 2.5 Pro") { viewModel.selectCustomModel("Gemini 2.5 Pro") }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var isExecuting: Bool {
        if case .executing = viewModel.homeUI.viewState { return true }
        return false
    }
}

#Preview {
    ContentView()
}
