import SwiftUI
import ImagePlayground

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(\.openURL) private var openURL

    private var promptBinding: Binding<String> {
        Binding(
            get: { viewModel.uiModel.prompt },
            set: { viewModel.updatePrompt($0) }
        )
    }

    private var attachedFilesBinding: Binding<[URL]> {
        Binding(
            get: { viewModel.uiModel.attachedFiles },
            set: { viewModel.updateAttachedFiles($0) }
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
                    PromptCardView(
                        prompt: promptBinding,
                        attachedFiles: attachedFilesBinding,
                        consumedTokenCount: viewModel.uiModel.consumedTokenCount
                    )
                    RunAgentButton(isRunning: isExecuting) {
                        viewModel.toggleExecutionState()
                    }
                    .disabled(!isExecuting && !viewModel.canRunAgent)
                    CompletedResultCard(
                        viewState: viewModel.viewState,
                        model: viewModel.uiModel,
                        elapsedTime: viewModel.elapsedTime,
                        onToggleSpeechPlayback: { viewModel.toggleSpeechPlayback() },
                        onStopSpeechPlayback: { viewModel.stopSpeechPlayback() }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(Colors.page.ignoresSafeArea())
        .preferredColorScheme(.light)
        .imagePlaygroundGenerationStyle(
            viewModel.imageGenerationRequest?.style.playgroundStyle ?? .any
        )
        .imagePlaygroundSheet(
            isPresented: imagePlaygroundBinding,
            concepts: imagePlaygroundConcepts,
            onCompletion: { viewModel.didCreateImage(at: $0) },
            onCancellation: { viewModel.cancelledImageGeneration() }
        )
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

    private var imagePlaygroundBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isImagePlaygroundPresented },
            set: { viewModel.isImagePlaygroundPresented = $0 }
        )
    }

    private var imagePlaygroundConcepts: [ImagePlaygroundConcept] {
        guard let request = viewModel.imageGenerationRequest else { return [] }
        return [.text(request.description)]
    }
}

#Preview {
    HomeView()
}
