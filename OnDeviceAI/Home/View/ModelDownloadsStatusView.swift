import SwiftUI

struct ModelDownloadsStatusView: View {
    let downloads: [ModelDownloadStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Colors.blue)
                Text("Downloading Models")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Colors.ink)
                Spacer()
                Text("\(downloads.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Colors.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Colors.blue.opacity(0.1), in: Capsule())
            }

            ForEach(downloads) { download in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(download.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Colors.control)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 8)
                        if let progress = download.progress {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Colors.blue)
                        } else {
                            Text(download.phase == .preparing ? "Preparing" : "Downloading")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Colors.muted)
                        }
                    }

                    if let progress = download.progress {
                        ProgressView(value: progress)
                            .tint(Colors.blue)
                    } else {
                        ProgressView()
                            .tint(Colors.blue)
                    }
                }
            }
        }
        .padding(16)
        .background(Colors.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Colors.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}
