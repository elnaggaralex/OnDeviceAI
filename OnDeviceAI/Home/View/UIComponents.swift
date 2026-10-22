import SwiftUI

struct AgentHeaderView: View {
    var body: some View {
        HStack(spacing: 5) {
            Text("On-Device AI")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .tracking(-0.55)
                .foregroundStyle(Colors.ink)
            Circle().fill(Colors.purple.opacity(0.72)).frame(width: 15, height: 15)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .overlay(alignment: .bottom) { Color.black.opacity(0.045).frame(height: 1) }
    }
}

struct AgentModePicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("Model type", selection: $selection) {
            Label("Apple Intelligence", systemImage: "sparkles")
                .tag(0)
            Label("Custom Model", systemImage: "cpu")
                .tag(1)
        }
        .pickerStyle(.segmented)
        .tint(Colors.purple)
        .frame(height: 40)
    }
}

struct ModelCardView: View {
    let selectedMode: Int
    let modelName: String
    let onSwitch: () -> Void

    var body: some View {
        Group {
            if selectedMode == 0 {
                OnDeviceModelInfoView()
            } else {
                CustomModelSelectionView(modelName: modelName, onSwitch: onSwitch)
            }
        }
        .padding(12)
        .background(Colors.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Colors.border, lineWidth: 1))
    }
}

private struct OnDeviceModelInfoView: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11)
                .fill(Colors.surfaceInset)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Colors.blue)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("Apple Intelligence")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Colors.ink)
                Text("Uses on-device models. Write your prompt below to get started.")
                    .font(.system(size: 12))
                    .foregroundStyle(Colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CustomModelSelectionView: View {
    let modelName: String
    let onSwitch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11)
                .fill(Colors.surfaceInset)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Colors.blue)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(modelName)
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.35)
                        .foregroundStyle(Colors.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("v2")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Colors.muted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 5))
                }
                Text("Context: 200k • Fast Multi-step\nReasoning")
                    .font(.system(size: 12))
                    .foregroundStyle(Colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 2)
            Button(action: onSwitch) {
                HStack(spacing: 5) {
                    Text("Switch").font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Colors.blue)
            }
        }
    }
}

struct PromptCardView: View {
    @Binding var prompt: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Colors.purple)
                Text("PROMPT")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Colors.label)
                Spacer()
                Text("\(prompt.count) chars")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Colors.muted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Colors.surfaceInset, in: Capsule())
            }

            SeparatorView()

            TextField("Write a prompt…", text: $prompt, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(Colors.ink)
                .lineSpacing(5)
                .lineLimit(3...5)
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)

            SeparatorView()

            HStack {
                Button {} label: {
                    Image(systemName: "mic")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Colors.control)
                        .frame(width: 28, height: 28)
                }
                Button {} label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Colors.control)
                        .frame(width: 28, height: 28)
                }
                Spacer()
                Button("Clear") { prompt = "" }
                    .font(.system(size: 12))
                    .foregroundStyle(Colors.muted)
                    .padding(.trailing, 4)
                Text("\(max(0, (prompt.count + 4) / 5)) Tokens")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Colors.control)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Colors.surfacePill, in: Capsule())
            }
        }
        .padding(16)
        .background(Colors.surface, in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(Colors.border, lineWidth: 1))
    }
}

private struct SeparatorView: View {
    var body: some View {
        Colors.separator.frame(height: 0.7)
    }
}

struct RunAgentButton: View {
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75), action)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isRunning ? "sparkles" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                Text(isRunning ? "Agent Running…" : "Run Agent")
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(-0.3)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background {
                LinearGradient(
                    colors: [Colors.buttonBlue, Colors.purple, Colors.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.35), lineWidth: 1))
            .shadow(color: Colors.blue.opacity(0.22), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

struct CompletedResultCard: View {
    let viewState: ViewState
    let model: UIModel
    let elapsedTime: TimeInterval

    var body: some View {
        VStack(spacing: 0) {
            CompletedStatusHeader(viewState: viewState, model: model, elapsedTime: elapsedTime)
            ModelResponseView(responseText: model.responseText)
        }
        .background(Colors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Colors.border, lineWidth: 1)
        }
        .padding(.top, 4)
    }
}

struct CompletedStatusHeader: View {
    let viewState: ViewState
    let model: UIModel
    let elapsedTime: TimeInterval

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle().fill(statusColor).frame(width: 7, height: 7)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Colors.ink)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Colors.surfacePill, in: Capsule())

            Text(modelName)
                .font(.system(size: 13))
                .foregroundStyle(Colors.muted)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 20
            )
            .fill(Colors.surfaceMuted)
        }
    }

    private var statusText: String {
        switch viewState {
        case .executing:
            return "Running • \(String(format: "%.1fs", elapsedTime))"
        case .executed(let result):
            return "Completed • \(result.completionDuration)"
        case .failed:
            return "Failed"
        }
    }

    private var modelName: String {
        switch viewState {
        case .executed(let result): return result.modelName
        case .executing, .failed: return model.modelName
        }
    }

    private var statusColor: Color {
        switch viewState {
        case .executing, .executed: return Colors.success
        case .failed: return Colors.error
        }
    }
}

struct ModelResponseView: View {
    let responseText: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Colors.blue)
                Text("Model Response")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Colors.blue)
                Spacer()
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            .overlay(alignment: .bottom) { Color.black.opacity(0.05).frame(height: 1) }

            Text(responseText.isEmpty ? "Generated response will appear here." : responseText)
                .font(.system(size: 14))
                .foregroundStyle(Colors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(16)
        }
    }
}
