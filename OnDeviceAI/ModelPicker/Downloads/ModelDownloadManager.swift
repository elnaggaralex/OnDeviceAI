import Foundation
import Observation

@MainActor
@Observable
final class ModelDownloadManager {
    private(set) var activeDownloads: [ModelDownloadStatus] = []
    private(set) var downloadedRepositoryIDs: Set<String>
    private(set) var errorsByRepositoryID: [String: String] = [:]

    private let downloader: HuggingFaceModelDownloader
    private var tasks: [String: Task<Void, Never>] = [:]

    init() {
        let downloader = HuggingFaceModelDownloader()
        self.downloader = downloader
        downloadedRepositoryIDs = downloader.installedRepositoryIDs()
    }

    func isDownloaded(repositoryID: String) -> Bool {
        if downloadedRepositoryIDs.contains(repositoryID) { return true }
        guard downloader.isDownloaded(repositoryID: repositoryID) else { return false }
        downloadedRepositoryIDs.insert(repositoryID)
        return true
    }

    func download(for repositoryID: String) -> ModelDownloadStatus? {
        activeDownloads.first { $0.repositoryID == repositoryID }
    }

    func error(for repositoryID: String) -> String? {
        errorsByRepositoryID[repositoryID]
    }

    func startDownload(for model: AIModelOption) {
        startDownload(repositoryID: model.repositoryID, displayName: model.name)
    }

    func startDownload(repositoryID: String, displayName: String) {
        guard tasks[repositoryID] == nil, !isDownloaded(repositoryID: repositoryID) else { return }

        errorsByRepositoryID[repositoryID] = nil
        activeDownloads.append(
            ModelDownloadStatus(
                repositoryID: repositoryID,
                displayName: displayName,
                phase: .preparing,
                progress: nil
            )
        )

        tasks[repositoryID] = Task { [weak self] in
            await self?.performDownload(repositoryID: repositoryID, displayName: displayName)
        }
    }

    private func performDownload(repositoryID: String, displayName: String) async {
        do {
            try await downloader.download(
                repositoryID: repositoryID,
                displayName: displayName
            ) { [weak self] progress in
                self?.updateDownload(repositoryID: repositoryID, progress: progress)
            }
            downloadedRepositoryIDs.insert(repositoryID)
            activeDownloads.removeAll { $0.repositoryID == repositoryID }
        } catch {
            activeDownloads.removeAll { $0.repositoryID == repositoryID }
            errorsByRepositoryID[repositoryID] = error.localizedDescription
        }
        tasks[repositoryID] = nil
    }

    private func updateDownload(repositoryID: String, progress: Double?) {
        guard let index = activeDownloads.firstIndex(where: { $0.repositoryID == repositoryID }) else { return }
        activeDownloads[index].phase = .downloading
        activeDownloads[index].progress = progress.map { min(1, max(0, $0)) }
    }
}

struct ModelDownloadStatus: Identifiable {
    let repositoryID: String
    let displayName: String
    var phase: Phase
    var progress: Double?

    var id: String { repositoryID }

    enum Phase: Equatable {
        case preparing
        case downloading
    }
}
