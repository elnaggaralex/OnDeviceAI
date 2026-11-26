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
    #if DEBUG
    private var lastPilotProgressByRepositoryID: [String: Int] = [:]
    #endif

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

    func languageModelBundleURL(repositoryID: String) -> URL? {
        downloader.languageModelBundleURL(repositoryID: repositoryID)
    }

    func audio8ModelDirectoryURL(repositoryID: String) -> URL? {
        downloader.audio8ModelDirectoryURL(repositoryID: repositoryID)
    }

    func imageToTextModelDirectories(repositoryID: String) -> ImageToTextModelDirectories? {
        downloader.imageToTextModelDirectories(repositoryID: repositoryID)
    }

    func miniCPMV46ModelDirectories(repositoryID: String) -> VisionLanguageModelDirectories? {
        downloader.miniCPMV46ModelDirectories(repositoryID: repositoryID)
    }

    func speechRecognitionBundleURL(repositoryID: String) -> URL? {
        downloader.speechRecognitionBundleURL(repositoryID: repositoryID)
    }

    func objectDetectionModelURL(repositoryID: String) -> URL? {
        downloader.objectDetectionModelURL(repositoryID: repositoryID)
    }

    func imageSegmentationBundleURL(repositoryID: String) -> URL? {
        downloader.imageSegmentationBundleURL(repositoryID: repositoryID)
    }

    func flux2IOSModelDirectoryURL(repositoryID: String) -> URL? {
        downloader.flux2IOSModelDirectoryURL(repositoryID: repositoryID)
    }

    func downloadSize(repositoryID: String) async throws -> Int64 {
        try await downloader.downloadSize(repositoryID: repositoryID)
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

    #if DEBUG
    func downloadForPilot(repositoryID: String, displayName: String) async throws {
        guard !isDownloaded(repositoryID: repositoryID) else { return }
        print("PILOT DOWNLOAD START \(repositoryID)")
        try await downloader.download(repositoryID: repositoryID, displayName: displayName) { progress in
            guard let progress else { return }
            let percent = Int(progress * 100)
            guard percent >= 10, percent.isMultiple(of: 10),
                  self.lastPilotProgressByRepositoryID[repositoryID] != percent else { return }
            self.lastPilotProgressByRepositoryID[repositoryID] = percent
            if percent.isMultiple(of: 10) {
                print("PILOT DOWNLOAD \(repositoryID) \(percent)%")
            }
        }
        lastPilotProgressByRepositoryID[repositoryID] = nil
        downloadedRepositoryIDs.insert(repositoryID)
        print("PILOT DOWNLOAD COMPLETE \(repositoryID)")
    }
    #endif

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
