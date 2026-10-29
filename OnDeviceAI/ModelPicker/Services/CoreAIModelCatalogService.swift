import Foundation

struct CoreAIModelCatalogService {
    private let session: URLSession
    private let initialCatalogURL = URL(
        string: "https://huggingface.co/api/models?author=coreai-community&limit=1000"
    )!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchModels() async throws -> [AIModelOption] {
        var nextURL: URL? = initialCatalogURL
        var repositories: [String: HubModelSummary] = [:]

        while let url = nextURL {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("OnDeviceAI/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ModelCatalogError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw ModelCatalogError.httpStatus(httpResponse.statusCode)
            }

            for model in try JSONDecoder().decode([HubModelSummary].self, from: data) {
                repositories[model.id] = model
            }
            nextURL = nextPageURL(in: httpResponse.value(forHTTPHeaderField: "Link"))
        }

        return repositories.values
            .map(makeModelOption(from:))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func makeModelOption(from model: HubModelSummary) -> AIModelOption {
        let task = model.pipelineTag.map(Self.displayName(for:)) ?? "Core AI model"
        let license = model.tags?.first(where: { $0.hasPrefix("license:") })
            .map { String($0.dropFirst("license:".count)) } ?? "License not listed"

        return AIModelOption(
            repositoryID: model.id,
            name: model.id.split(separator: "/").last.map(String.init) ?? model.id,
            task: task,
            license: license,
            downloads: model.downloads ?? 0,
            likes: model.likes ?? 0,
            category: AIModelCategory(task: (model.pipelineTag ?? "").lowercased())
        )
    }

    private func nextPageURL(in linkHeader: String?) -> URL? {
        guard let linkHeader else { return nil }
        for link in linkHeader.split(separator: ",") {
            let components = link.split(separator: ";", maxSplits: 1)
            guard components.count == 2,
                  components[1].contains("rel=\"next\"") || components[1].contains("rel=next") else {
                continue
            }
            let value = components[0].trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
            return URL(string: value)
        }
        return nil
    }

    private static func displayName(for value: String) -> String {
        value.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

private struct HubModelSummary: Decodable {
    let id: String
    let pipelineTag: String?
    let tags: [String]?
    let downloads: Int?
    let likes: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case pipelineTag = "pipeline_tag"
        case tags
        case downloads
        case likes
    }
}

private enum ModelCatalogError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Hugging Face returned an invalid model catalog response."
        case .httpStatus(let statusCode):
            "Hugging Face could not load the model catalog (HTTP \(statusCode))."
        }
    }
}
