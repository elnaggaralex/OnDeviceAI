import Foundation

struct CoreAIModelCatalogService {
    private let session: URLSession
    private let catalogAuthors = ["coreai-community", "mlboydaisuke", "grabbou"]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchModels() async throws -> [AIModelOption] {
        var repositories: [String: HubModelSummary] = [:]

        for author in catalogAuthors {
            var components = URLComponents(string: "https://huggingface.co/api/models")!
            components.queryItems = [
                URLQueryItem(name: "author", value: author),
                URLQueryItem(name: "limit", value: "1000"),
                URLQueryItem(name: "expand[]", value: "siblings"),
                URLQueryItem(name: "expand[]", value: "tags"),
                URLQueryItem(name: "expand[]", value: "pipeline_tag"),
                URLQueryItem(name: "expand[]", value: "downloads"),
                URLQueryItem(name: "expand[]", value: "likes")
            ]
            var nextURL = components.url

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

                let models = try JSONDecoder().decode([HubModelSummary].self, from: data)
                for model in models where isCoreAIExport(model, by: author) && hasIOSBundle(model) {
                    repositories[model.id] = model
                }
                nextURL = nextPageURL(in: httpResponse.value(forHTTPHeaderField: "Link"))
            }
        }

        var uniqueByModel: [String: HubModelSummary] = [:]
        for model in repositories.values {
            let key = canonicalModelKey(for: model.id)
            guard let current = uniqueByModel[key] else {
                uniqueByModel[key] = model
                continue
            }
            if repositoryPriority(model.id) < repositoryPriority(current.id) {
                uniqueByModel[key] = model
            }
        }

        return uniqueByModel.values
            .map(makeModelOption(from:))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func isCoreAIExport(_ model: HubModelSummary, by author: String) -> Bool {
        guard author != "coreai-community" else { return true }
        return model.tags?.contains(where: {
            $0.caseInsensitiveCompare("coreai") == .orderedSame
                || $0.caseInsensitiveCompare("coreai-aimodel") == .orderedSame
        }) == true
    }

    private func hasIOSBundle(_ model: HubModelSummary) -> Bool {
        let paths = model.siblings?.map(\.filename) ?? []
        let hasIOSDirectoryBundle = paths.contains { path in
            let components = path.split(separator: "/")
            guard components.contains(where: isIOSDirectoryName) else { return false }

            // Hugging Face expands .aimodel/.aimodelc bundles as directories. The
            // sibling filenames therefore usually end in metadata.json or weights,
            // with the bundle extension in a parent path component.
            return components.contains(where: isModelBundleName)
        }
        if hasIOSDirectoryBundle { return true }

        let hasRootBundle = paths.contains { path in
            path.split(separator: "/").contains(where: isModelBundleName)
        }
        let hasIOSTag = model.tags?.contains(where: {
            let tag = $0.lowercased()
            return tag == "ios" || tag.hasPrefix("ios-")
        }) == true
        return hasRootBundle && hasIOSTag
    }

    private func isIOSDirectoryName(_ component: Substring) -> Bool {
        let value = component.lowercased()
        return value == "ios" || value.hasPrefix("ios-") || value.hasPrefix("ios_")
            || value == "iphone" || value.hasPrefix("iphone-") || value.hasPrefix("iphone_")
    }

    private func isModelBundleName(_ component: Substring) -> Bool {
        let value = component.lowercased()
        return value.hasSuffix(".aimodel") || value.hasSuffix(".aimodelc")
    }

    private func canonicalModelKey(for repositoryID: String) -> String {
        var name = repositoryID.split(separator: "/").last.map(String.init)?.lowercased() ?? repositoryID.lowercased()
        for suffix in ["-coreai-official", "-coreai", "-official"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        return String(name.filter { $0.isLetter || $0.isNumber })
    }

    private func repositoryPriority(_ repositoryID: String) -> Int {
        repositoryID.lowercased().hasPrefix("coreai-community/") ? 0 : 1
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

    nonisolated private static func displayName(for value: String) -> String {
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
    let siblings: [HubModelSibling]?

    enum CodingKeys: String, CodingKey {
        case id
        case pipelineTag = "pipeline_tag"
        case tags
        case downloads
        case likes
        case siblings
    }
}

private struct HubModelSibling: Decodable {
    let filename: String

    enum CodingKeys: String, CodingKey {
        case filename = "rfilename"
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
