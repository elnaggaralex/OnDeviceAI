import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    private var promptBinding: Binding<String> {
        Binding(
            get: { viewModel.uiModel.prompt },
            set: { viewModel.updatePrompt($0) }
        )
    }

    private var modeBinding: Binding<Int> {
        Binding(
            get: { viewModel.uiModel.selectedMode },
            set: { viewModel.selectMode($0) }
        )
    }

    private var modelPickerBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isModelPickerPresented },
            set: { viewModel.isModelPickerPresented = $0 }
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                AgentHeaderView()

                VStack(spacing: 16) {
                    AgentModePicker(selection: modeBinding)
                    ModelCardView(
                        selectedMode: viewModel.uiModel.selectedMode,
                        modelName: viewModel.uiModel.customModelName
                    ) {
                        viewModel.isModelPickerPresented = true
                    }
                    PromptCardView(prompt: promptBinding)
                    RunAgentButton(isRunning: isExecuting) {
                        viewModel.toggleExecutionState()
                    }
                    CompletedResultCard(
                        viewState: viewModel.viewState,
                        model: viewModel.uiModel
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(Colors.page.ignoresSafeArea())
        .preferredColorScheme(.light)
        .sheet(isPresented: modelPickerBinding) {
            ModelPickerSheet(selectedModel: viewModel.uiModel.customModelName) { model in
                viewModel.selectCustomModel(model)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
        }
    }

    private var isExecuting: Bool {
        if case .executing = viewModel.viewState { return true }
        return false
    }
}

#Preview {
    HomeView()
}
