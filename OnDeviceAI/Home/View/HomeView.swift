import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(\.openURL) private var openURL

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
                    .disabled(!isExecuting && viewModel.uiModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    CompletedResultCard(
                        viewState: viewModel.viewState,
                        model: viewModel.uiModel,
                        elapsedTime: viewModel.elapsedTime
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(Colors.page.ignoresSafeArea())
        .preferredColorScheme(.light)
        .task {
            viewModel.checkAppleIntelligenceAvailability()
        }
        .alert("Enable Apple Intelligence", isPresented: $viewModel.isAppleIntelligenceEnableAlertPresented) {
            Button("OK") {
                if let settingsURL = URL(string: "App-prefs:APPLE_INTELLIGENCE") {
                    openURL(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Apple Intelligence is available on this device but is turned off. You can enable it in Settings to use the on-device model.")
        }
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
