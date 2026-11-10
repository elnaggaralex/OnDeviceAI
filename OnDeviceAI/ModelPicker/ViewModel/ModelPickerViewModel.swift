import Foundation
import Observation

@MainActor
@Observable
final class ModelPickerViewModel {
    private(set) var query = ""
    private(set) var selectedFilter: ModelPickerFilter = .all
    private(set) var selectedModel: String
    private(set) var models: [AIModelOption] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var downloadSizes: [String: Int64] = [:]
    private var sizeLookupsInProgress: Set<String> = []
    private(set) var unavailableDownloadSizes: Set<String> = []

    private let catalog: CoreAIModelCatalogService
    let downloadManager: ModelDownloadManager

    init(
        selectedModel: String,
        downloadManager: ModelDownloadManager,
        catalog: CoreAIModelCatalogService? = nil
    ) {
        self.selectedModel = selectedModel
        self.downloadManager = downloadManager
        self.catalog = catalog ?? CoreAIModelCatalogService()
    }

    var filteredModels: [AIModelOption] {
        models.filter { model in
            let matchesQuery = query.isEmpty ||
                "\(model.name) \(model.repositoryID) \(model.task) \(model.license)"
                    .localizedCaseInsensitiveContains(query)
            let matchesFilter: Bool
            switch selectedFilter {
            case .all: matchesFilter = true
            case .text: matchesFilter = model.category == .text
            case .vision: matchesFilter = model.category == .vision
            case .audio: matchesFilter = model.category == .audio
            case .other: matchesFilter = model.category == .other
            }
            return matchesQuery && matchesFilter
        }.sorted { lhs, rhs in
            let lhsPriority = listPriority(for: lhs)
            let rhsPriority = listPriority(for: rhs)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func listPriority(for model: AIModelOption) -> Int {
        if downloadManager.isDownloaded(repositoryID: model.repositoryID) { return 0 }
        if downloadManager.download(for: model.repositoryID) != nil { return 1 }
        return 2
    }

    func downloadSize(for model: AIModelOption) -> Int64? {
        downloadSizes[model.repositoryID]
    }

    func downloadSizeUnavailable(for model: AIModelOption) -> Bool {
        unavailableDownloadSizes.contains(model.repositoryID)
    }

    func loadDownloadSize(for model: AIModelOption) async {
        let repositoryID = model.repositoryID
        guard downloadSizes[repositoryID] == nil,
              sizeLookupsInProgress.insert(repositoryID).inserted else {
            return
        }
        defer { sizeLookupsInProgress.remove(repositoryID) }

        do {
            downloadSizes[repositoryID] = try await downloadManager.downloadSize(repositoryID: repositoryID)
        } catch is CancellationError {
            return
        } catch {
            unavailableDownloadSizes.insert(repositoryID)
        }
    }

    func loadModels() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loadedModels = try await catalog.fetchModels()
            models = loadedModels
            if !loadedModels.contains(where: { $0.repositoryID == selectedModel }),
               let firstModel = loadedModels.first {
                selectedModel = firstModel.repositoryID
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func search(for query: String) {
        self.query = query
    }

    func selectFilter(_ filter: ModelPickerFilter) {
        selectedFilter = filter
    }

    func selectModel(_ model: AIModelOption) {
        selectedModel = model.repositoryID
    }

    func download(_ model: AIModelOption) {
        downloadManager.startDownload(for: model)
    }
}

enum ModelPickerFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case vision
    case audio
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .text: "Text"
        case .vision: "Vision"
        case .audio: "Audio"
        case .other: "Other"
        }
    }
}
