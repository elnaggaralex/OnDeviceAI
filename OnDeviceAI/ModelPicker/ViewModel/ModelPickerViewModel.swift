import Observation
import Foundation

@MainActor
@Observable
final class ModelPickerViewModel {
    private(set) var query = ""
    private(set) var selectedFilter: ModelPickerFilter = .all
    private(set) var selectedModel: String

    let filters = ModelPickerFilter.allCases

    private let models = [
        AIModelOption(
            name: "DeepSeek-R1 Distill 7B", family: "Reasoning", icon: "brain.head.profile",
            source: "Local MLX • 128K ctx • 4.8 GB • INT4", detail: "Ready on device • Neural Engine + GPU",
            size: "4.8 GB", downloaded: true, reasoning: true, small: false
        ),
        AIModelOption(
            name: "Qwen 2.5 7B", family: "Instruct", icon: "brain.fill",
            source: "Local GGUF Q4_K_M • 32K ctx • 4.4 GB", detail: "4-bit Quant • High Multilingual Accuracy",
            size: "4.4 GB", downloaded: false, reasoning: false, small: false
        ),
        AIModelOption(
            name: "Gemma 2 2B", family: "MLX", icon: "diamond.fill",
            source: "Apple MLX • 8K ctx • 1.6 GB", detail: "Ultra-low RAM • 62 t/s on Apple Silicon",
            size: "1.6 GB", downloaded: false, reasoning: false, small: true
        ),
        AIModelOption(
            name: "Llama 3.2 3B", family: "Local", icon: "cpu.fill",
            source: "Local MLX • 8K ctx • 2.0 GB", detail: "Fast responses • Optimized for mobile",
            size: "2.0 GB", downloaded: false, reasoning: false, small: true
        )
    ]

    init(selectedModel: String) {
        let names = ["DeepSeek-R1 Distill 7B", "Qwen 2.5 7B", "Gemma 2 2B", "Llama 3.2 3B"]
        self.selectedModel = names.contains(selectedModel) ? selectedModel : names[0]
    }

    var filteredModels: [AIModelOption] {
        models.filter { model in
            let matchesQuery = query.isEmpty ||
                "\(model.name) \(model.family) \(model.source)".localizedCaseInsensitiveContains(query)
            let matchesFilter: Bool
            switch selectedFilter {
            case .all: matchesFilter = true
            case .downloaded: matchesFilter = model.downloaded
            case .small: matchesFilter = model.small
            case .reasoning: matchesFilter = model.reasoning
            }
            return matchesQuery && matchesFilter
        }
    }

    func search(for query: String) {
        self.query = query
    }

    func selectFilter(_ filter: ModelPickerFilter) {
        selectedFilter = filter
    }

    func selectModel(_ model: AIModelOption) {
        selectedModel = model.name
    }
}

enum ModelPickerFilter: String, CaseIterable, Identifiable {
    case all
    case downloaded
    case small
    case reasoning

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "All"
        case .downloaded: return "Downloaded"
        case .small: return "Small (<4B)"
        case .reasoning: return "Reasoning"
        }
    }
}

struct AIModelOption: Identifiable {
    var id: String { name }
    let name: String
    let family: String
    let icon: String
    let source: String
    let detail: String
    let size: String
    let downloaded: Bool
    let reasoning: Bool
    let small: Bool
}
