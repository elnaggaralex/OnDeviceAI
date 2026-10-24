import SwiftUI
import FoundationModels
import PhotosUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
private typealias AttachmentImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias AttachmentImage = NSImage
#endif

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
    @Binding var attachedFiles: [URL]
    let consumedTokenCount: Int?
    @State private var isAttachmentPickerPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

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

            if !attachedFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(attachedFiles, id: \.self) { fileURL in
                            AttachmentPreviewView(fileURL: fileURL) {
                                attachedFiles.removeAll { $0 == fileURL }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            SeparatorView()

            HStack {
                Button {} label: {
                    Image(systemName: "mic")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Colors.control)
                        .frame(width: 28, height: 28)
                }
                Menu {
                    Button {
                        isAttachmentPickerPresented = true
                    } label: {
                        Label("Choose Files", systemImage: "doc")
                    }
                    Button {
                        isPhotoPickerPresented = true
                    } label: {
                        Label("Choose Photos", systemImage: "photo")
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Colors.control)
                        .frame(width: 28, height: 28)
                        .overlay(alignment: .topTrailing) {
                            if !attachedFiles.isEmpty {
                                Text("\(attachedFiles.count)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 13, minHeight: 13)
                                    .background(Colors.purple, in: Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                }
                .fileImporter(
                    isPresented: $isAttachmentPickerPresented,
                    allowedContentTypes: [.text, .image, .audio],
                    allowsMultipleSelection: true
                ) { result in
                    if case let .success(urls) = result {
                        var uniqueURLs: [URL] = []
                        for url in attachedFiles + urls where !uniqueURLs.contains(url) {
                            uniqueURLs.append(url)
                        }
                        attachedFiles = uniqueURLs
                    }
                }
                .photosPicker(
                    isPresented: $isPhotoPickerPresented,
                    selection: $selectedPhotoItems,
                    matching: .images
                )
                .onChange(of: selectedPhotoItems) { _, items in
                    guard !items.isEmpty else { return }
                    Task {
                        await importPhotos(items)
                    }
                }
                Spacer()
                Button("Clear") { prompt = "" }
                    .font(.system(size: 12))
                    .foregroundStyle(Colors.muted)
                    .padding(.trailing, 4)
                Text("\(consumedTokenCount.map(String.init) ?? "—") tokens")
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

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        var importedURLs: [URL] = []

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let fileExtension = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("photo-\(UUID().uuidString)")
                .appendingPathExtension(fileExtension)

            do {
                try data.write(to: destination, options: .atomic)
                importedURLs.append(destination)
            } catch {
                continue
            }
        }

        attachedFiles.append(contentsOf: importedURLs)
        selectedPhotoItems = []
    }
}

private struct AttachmentPreviewView: View {
    let fileURL: URL
    let onRemove: () -> Void
    @State private var thumbnail: AttachmentImage?

    private var isImage: Bool {
        UTType(filenameExtension: fileURL.pathExtension)?.conforms(to: .image) == true
    }

    private var fileIcon: String {
        if UTType(filenameExtension: fileURL.pathExtension)?.conforms(to: .audio) == true {
            return "waveform"
        }
        return "doc.text"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topTrailing) {
                if isImage {
                    imageThumbnail
                        .frame(width: 76, height: 60)
                } else {
                    Image(systemName: fileIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Colors.blue)
                        .frame(width: 76, height: 60)
                }

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(3)
                .accessibilityLabel("Remove \(fileURL.lastPathComponent)")
            }
            .background(Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 9))
            .clipShape(RoundedRectangle(cornerRadius: 9))

            Text(fileURL.lastPathComponent)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Colors.label)
                .lineLimit(1)
                .frame(width: 76, alignment: .leading)
        }
        .task(id: fileURL) {
            guard isImage else { return }
            let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            #if canImport(UIKit)
            thumbnail = UIImage(contentsOfFile: fileURL.path)
            #elseif canImport(AppKit)
            thumbnail = NSImage(contentsOf: fileURL)
            #endif
        }
    }

    @ViewBuilder
    private var imageThumbnail: some View {
        if let thumbnail {
            #if canImport(UIKit)
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
            #elseif canImport(AppKit)
            Image(nsImage: thumbnail)
                .resizable()
                .scaledToFill()
            #endif
        } else {
            Image(systemName: "photo")
                .font(.system(size: 20))
                .foregroundStyle(Colors.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
    let onToggleSpeechPlayback: () -> Void
    let onStopSpeechPlayback: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            CompletedStatusHeader(viewState: viewState, model: model, elapsedTime: elapsedTime)
            ModelResponseView(
                response: model.structuredResponse,
                errorMessage: model.errorMessage,
                speechText: model.speechText,
                speechStyle: model.speechStyle,
                speechGender: model.speechGender,
                imageGenerationRequest: model.imageGenerationRequest,
                generatedImageURL: model.generatedImageURL,
                speechPlaybackState: model.speechPlaybackState,
                onToggleSpeechPlayback: onToggleSpeechPlayback,
                onStopSpeechPlayback: onStopSpeechPlayback
            )
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
    let response: TextTaskResult.PartiallyGenerated?
    let errorMessage: String?
    let speechText: String?
    let speechStyle: RequestedSpeechStyle?
    let speechGender: RequestedSpeechGender?
    let imageGenerationRequest: ImageGenerationRequest?
    let generatedImageURL: URL?
    let speechPlaybackState: SpeechPlaybackState
    let onToggleSpeechPlayback: () -> Void
    let onStopSpeechPlayback: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: generatedImageURL != nil ? "photo" : (speechText == nil ? "text.bubble" : "waveform"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Colors.blue)
                Text(generatedImageURL != nil ? "Generated Image" : (speechText == nil ? "Model Response" : "Generated Speech"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Colors.blue)
                Spacer()
            }
            .frame(height: 44)
            .padding(.horizontal, 16)
            .overlay(alignment: .bottom) { Color.black.opacity(0.05).frame(height: 1) }

            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Couldn’t complete the request")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Colors.ink)
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(Colors.muted)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            } else if let generatedImageURL {
                VStack(alignment: .leading, spacing: 10) {
                    GeneratedImagePreview(url: generatedImageURL)
                    if let imageGenerationRequest {
                        Text(imageGenerationRequest.description)
                            .font(.system(size: 13))
                            .foregroundStyle(Colors.ink)
                            .textSelection(.enabled)
                    }
                    Text("Created with Image Playground")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Colors.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            } else if let speechText {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Button(action: onToggleSpeechPlayback) {
                            Label(speechPlaybackButtonTitle, systemImage: speechPlaybackButtonIcon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Colors.blue, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        if speechPlaybackState != .idle {
                            Button(action: onStopSpeechPlayback) {
                                Label("Stop", systemImage: "stop.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Colors.control)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    if let speechStyle {
                        Text("Voice style: \(speechStyleLabel(speechStyle))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Colors.muted)
                    }

                    if let speechGender, speechGender != .unspecified {
                        Text("Speaker: \(speechGender == .male ? "Male" : "Female")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Colors.muted)
                    }

                    Text(speechText)
                        .font(.system(size: 14))
                        .foregroundStyle(Colors.ink)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            } else if let response {
                VStack(alignment: .leading, spacing: 14) {
                    if let title = response.title, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Colors.ink)
                    }

                    if let mainResponse = response.response, !mainResponse.isEmpty {
                        Text(mainResponse)
                            .font(.system(size: 14))
                            .foregroundStyle(Colors.ink)
                            .textSelection(.enabled)
                    }

                    if let keyPoints = response.keyPoints, !keyPoints.isEmpty {
                        StructuredResponseList(title: "Key points", items: keyPoints)
                    }

                    if let actionItems = response.actionItems, !actionItems.isEmpty {
                        StructuredResponseList(title: "Action items", items: actionItems)
                    }

                    if response.title == nil && response.response == nil
                        && response.keyPoints == nil && response.actionItems == nil {
                        Text("Generating structured response…")
                            .font(.system(size: 14))
                            .foregroundStyle(Colors.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            } else {
                Text("Generated response will appear here.")
                    .font(.system(size: 14))
                    .foregroundStyle(Colors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }

    private var speechPlaybackButtonTitle: String {
        switch speechPlaybackState {
        case .idle: return "Play"
        case .speaking: return "Pause"
        case .paused: return "Resume"
        }
    }

    private var speechPlaybackButtonIcon: String {
        switch speechPlaybackState {
        case .idle: return "play.fill"
        case .speaking: return "pause.fill"
        case .paused: return "play.fill"
        }
    }

    private func speechStyleLabel(_ style: RequestedSpeechStyle) -> String {
        switch style {
        case .natural: return "Natural"
        case .childlike: return "Childlike (pitch adjusted)"
        case .calm: return "Calm"
        case .energetic: return "Energetic"
        }
    }
}

private struct GeneratedImagePreview: View {
    let url: URL
    @State private var image: AttachmentImage?

    var body: some View {
        Group {
            if let image {
                #if canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                #elseif canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                #endif
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: 360)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task(id: url) {
            #if canImport(UIKit)
            image = UIImage(contentsOfFile: url.path)
            #elseif canImport(AppKit)
            image = NSImage(contentsOf: url)
            #endif
        }
        .accessibilityLabel("Generated image")
    }
}

private struct StructuredResponseList: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Colors.label)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Circle()
                        .fill(Colors.blue)
                        .frame(width: 4, height: 4)
                    Text(item)
                        .font(.system(size: 13))
                        .foregroundStyle(Colors.ink)
                        .textSelection(.enabled)
                }
            }
        }
    }
}
