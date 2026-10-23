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
            TextField("Search models, architectures, or context…", text: $query)
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
        case .downloaded: return "checkmark.circle"
        case .small: return "cpu"
        case .reasoning: return "brain.head.profile"
        }
    }

    private var iconColor: Color {
        switch filter {
        case .all: return Colors.control
        case .downloaded, .reasoning: return Colors.blue
        case .small: return Colors.purple
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
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 14) {
                modelIcon

                VStack(alignment: .leading, spacing: 5) {
                    title

                    Text(model.source)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Colors.control)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Image(systemName: model.downloaded ? "checkmark.circle" : "bolt.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(model.detail)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(model.downloaded ? Colors.blue : Colors.muted)
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
                trailingBadge
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Colors.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isSelected ? Colors.blue.opacity(0.55) : Colors.border.opacity(0.8), lineWidth: isSelected ? 1.5 : 1)
            }
            .shadow(color: isSelected ? Colors.purple.opacity(0.10) : .black.opacity(0.035), radius: isSelected ? 15 : 7, y: 4)
        }
        .buttonStyle(.plain)
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(model.family)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(model.reasoning ? Colors.purple : Colors.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((model.reasoning ? Colors.purple : Colors.blue).opacity(0.1), in: Capsule())
        }
    }

    @ViewBuilder
    private var trailingBadge: some View {
        if isSelected {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Colors.blue, in: Circle())
                .shadow(color: Colors.blue.opacity(0.22), radius: 6, y: 3)
        } else {
            HStack(spacing: 6) {
                Image(systemName: model.downloaded ? "checkmark.circle" : "icloud.and.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                Text(model.downloaded ? "Ready" : model.size)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(Colors.blue)
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(Colors.surfaceInset, in: Capsule())
        }
    }
}

struct DeviceStorageFooter: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Device Storage", systemImage: "externaldrive")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Colors.ink)
                Spacer()
                Text("14.8 GB free of 256 GB")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Colors.control)
            }

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    Colors.blue.frame(width: proxy.size.width * 0.72)
                    Colors.purple.frame(width: proxy.size.width * 0.14)
                    Colors.border.frame(maxWidth: .infinity)
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            Button {} label: {
                Label("Import Custom GGUF/CoreAI Model", systemImage: "plus.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Colors.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Colors.surfaceInset, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 12)
        .background(Colors.surface.opacity(0.97))
        .overlay(alignment: .top) { Colors.border.frame(height: 1) }
    }
}
