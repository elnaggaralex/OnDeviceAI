import SwiftUI

struct ContentView: View {
    @State private var selectedMode = 0
    @State private var prompt = "Analyze recent quarterly growth metrics for clean energy startups and synthesize an executive summary infographic."
    @State private var isRunning = false
    @State private var showingModelPicker = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                AgentHeaderView()

                VStack(spacing: 16) {
                    AgentModePicker(selection: $selectedMode)
                    ModelCardView(selectedMode: selectedMode) {
                        showingModelPicker = true
                    }
                    PromptCardView(prompt: $prompt)
                    RunAgentButton(isRunning: $isRunning)
                    CompletedResultCard(isRunning: isRunning)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(AppColors.page.ignoresSafeArea())
        .preferredColorScheme(.light)
        .confirmationDialog("Choose a model", isPresented: $showingModelPicker, titleVisibility: .visible) {
            Button("Claude 3.5 Sonnet") { }
            Button("GPT-4o") { }
            Button("Gemini 2.5 Pro") { }
            Button("Cancel", role: .cancel) { }
        }
    }
}

#Preview {
    ContentView()
}
