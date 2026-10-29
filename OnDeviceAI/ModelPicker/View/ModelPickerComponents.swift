import SwiftUI

struct ModelPickerHeaderView: View {
    let onDone: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(colors: [Colors.purple, Colors.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )

            Text("Select AI Model")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .tracking(-0.7)
                .foregroundStyle(Colors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 4)

            Button(action: onDone) {
                HStack(spacing: 6) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Colors.blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Colors.surfaceInset, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(Colors.surface.opacity(0.94))
        .overlay(alignment: .bottom) { Colors.border.frame(height: 1) }
    }
}

struct ModelSearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Colors.muted)
            TextField("Search models or tasks…", text: $query)
                .font(.system(size: 16))
                .tint(Colors.blue)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(Colors.muted.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Colors.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

struct ModelFilterBar: View {
    @Binding var selection: ModelPickerFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(ModelPickerFilter.allCases) { filter in
                    ModelFilterChip(filter: filter, isSelected: selection == filter) {
                        withAnimation(.snappy(duration: 0.2)) { selection = filter }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

private struct ModelFilterChip: View {
    let filter: ModelPickerFilter
    let isSelected: Bool
    let action: () -> Void

    private var icon: String? {
        switch filter {
        case .all: return nil
        case .text: return "text.alignleft"
        case .vision: return "viewfinder"
        case .audio: return "waveform"
        case .other: return "cpu"
        }
    }

    private var iconColor: Color {
        switch filter {
        case .all, .text, .vision, .audio: return Colors.blue
        case .other: return Colors.purple
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(isSelected ? .white : iconColor)
                }
                Text(filter.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Colors.control)
            }
            .padding(.horizontal, 15)
            .frame(height: 42)
            .background(isSelected ? Colors.ink : Colors.surfaceInset, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ModelOptionCard: View {
    let model: AIModelOption
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double?
    let downloadError: String?
    let onSelect: () -> Void
    let onDownload: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onSelect) {
                HStack(alignment: .top, spacing: 14) {
                    modelIcon

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            title
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Colors.blue, in: Circle())
                            }
                        }

                        Text(model.repositoryID)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Colors.control)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.top, 2)
                            Text("\(model.task) • \(model.license)")
                                .font(.system(size: 12, weight: .medium))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(Colors.muted)

                        if let downloadError {
                            Label(downloadError, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            downloadButton
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Colors.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(isSelected ? Colors.blue : Colors.border.opacity(0.8), lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: isSelected ? Colors.purple.opacity(0.10) : .black.opacity(0.035), radius: isSelected ? 15 : 7, y: 4)
    }

    private var modelIcon: some View {
        Image(systemName: model.icon)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(isSelected ? Colors.blue : Colors.purple)
            .frame(width: 58, height: 58)
            .background(isSelected ? Colors.surface : Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(isSelected ? Colors.purple.opacity(0.48) : Colors.border, lineWidth: 1.5))
    }

    private var title: some View {
        HStack(spacing: 7) {
            Text(model.name)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .tracking(-0.35)
                .foregroundStyle(Colors.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var downloadButton: some View {
        Group {
            if isDownloading {
                ZStack {
                    Circle()
                        .stroke(Colors.border, lineWidth: 3)
                    if let downloadProgress {
                        Circle()
                            .trim(from: 0, to: downloadProgress)
                            .stroke(Colors.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Colors.blue)
                    }
                }
                .frame(width: 38, height: 38)
                .accessibilityLabel(downloadProgress.map { "Downloading \(Int($0 * 100)) percent" } ?? "Preparing download")
            } else if isDownloaded {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Colors.blue)
                    .frame(width: 40, height: 40)
                    .background(Colors.surfaceInset, in: Circle())
                    .overlay(Circle().stroke(Colors.blue.opacity(0.35), lineWidth: 1))
                    .accessibilityLabel("Model downloaded")
            } else {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Colors.control)
                        .frame(width: 40, height: 40)
                        .background(Colors.surfaceInset, in: Circle())
                        .overlay(Circle().stroke(Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(downloadError == nil ? "Download model" : "Retry model download")
            }
        }
    }
}
