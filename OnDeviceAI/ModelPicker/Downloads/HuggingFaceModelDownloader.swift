import Foundation

private enum MiniCPMV46BundleVariant {
    static let all: [(decoder: String, vision: String)] = [
        ("gpu-pipelined/minicpmv46_vlm_decode_int8hu", "gpu-pipelined/minicpmv46_vision_int8lin"),
        ("gpu-pipelined/minicpmv46_vlm_decode_int8lin", "gpu-pipelined/minicpmv46_vision")
    ]
}

struct HuggingFaceModelDownloader {
    private let session: URLSession
    private let fileDownloader: ModelFileDownloadSession
    private let fileManager = FileManager.default
    private let storageRoot: URL

    init(session: URLSession = .shared) {
        self.session = session
        fileDownloader = ModelFileDownloadSession()
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        storageRoot = applicationSupport.appendingPathComponent("CoreAIModels", isDirectory: true)
    }

    func isDownloaded(repositoryID: String) -> Bool {
        guard let manifest = try? readManifest(repositoryID: repositoryID),
              manifest.repositoryID == repositoryID,
              manifestIsComplete(manifest, in: installedDirectory(repositoryID: repositoryID)) else { return false }
        return true
    }

    func languageModelBundleURL(repositoryID: String) -> URL? {
        guard isDownloaded(repositoryID: repositoryID),
              let manifest = try? readManifest(repositoryID: repositoryID) else { return nil }

        let root = installedDirectory(repositoryID: repositoryID)
        // HF exposes `.aimodel` bundles as directories containing `main.mlirb` and
        // `main.hash`; therefore the manifest contains their contents, not a `.aimodel` path.
        for metadataPath in manifest.files where URL(fileURLWithPath: metadataPath).lastPathComponent == "metadata.json" {
            let metadataURL = root.appending(path: metadataPath)
            guard let data = try? Data(contentsOf: metadataURL),
                  let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let kind = metadata["kind"] as? String, kind.lowercased().contains("llm"),
                  let assets = metadata["assets"] as? [String: Any],
                  let mainPath = assets["main"] as? String,
                  isSafeRelativePath(mainPath) else { continue }

            let bundleURL = metadataURL.deletingLastPathComponent()
            let modelURL = bundleURL.appending(path: mainPath)
            let parentPath = (metadataPath as NSString).deletingLastPathComponent
            let modelRelativePath = parentPath.isEmpty ? mainPath : parentPath + "/" + mainPath
            let hasModelFiles = manifest.files.contains { $0.hasPrefix(modelRelativePath + "/") }
            var isTokenizerDirectory: ObjCBool = false
            let tokenizerURL = bundleURL.appendingPathComponent("tokenizer", isDirectory: true)
            let hasTokenizer = fileManager.fileExists(atPath: tokenizerURL.path, isDirectory: &isTokenizerDirectory)
                && isTokenizerDirectory.boolValue
            guard hasModelFiles, fileManager.fileExists(atPath: modelURL.path), hasTokenizer else { continue }
            return bundleURL
        }
        return nil
    }

    func audio8ModelDirectoryURL(repositoryID: String) -> URL? {
        guard isDownloaded(repositoryID: repositoryID) else { return nil }
        let modelDirectory = installedDirectory(repositoryID: repositoryID)
        let requiredAssets = [
            "audio8_dualar_int8_cl2048_w32.aimodel",
            "audio8_codec_decoder_fp16_t160.aimodel"
        ]
        let tokenizerURL = modelDirectory.appendingPathComponent("tokenizer", isDirectory: true)
        var isTokenizerDirectory: ObjCBool = false
        guard requiredAssets.allSatisfy({
            fileManager.fileExists(atPath: modelDirectory.appendingPathComponent($0).path)
        }),
              fileManager.fileExists(atPath: tokenizerURL.path, isDirectory: &isTokenizerDirectory),
              isTokenizerDirectory.boolValue else {
            return nil
        }
        return modelDirectory
    }

    func imageToTextModelDirectories(repositoryID: String) -> ImageToTextModelDirectories? {
        guard isDownloaded(repositoryID: repositoryID) else { return nil }

        let root = installedDirectory(repositoryID: repositoryID)
        let visionDirectory = root.appendingPathComponent("vision", isDirectory: true)
        let decoderDirectory = root.appendingPathComponent("decoder", isDirectory: true)
        if repositoryID.caseInsensitiveCompare("coreai-community/Unlimited-OCR-CoreAI") == .orderedSame {
            let assetsDirectory = root.appendingPathComponent("assets", isDirectory: true)
            let tokenizerDirectory = root.appendingPathComponent("tokenizer", isDirectory: true)
            let requiredAssets = ["embed_tokens.f16", "image_newline.f16", "view_seperator.f16", "prompt_input_ids.i32"]
            guard hasModelBundle(in: visionDirectory), hasModelBundle(in: decoderDirectory),
                  requiredAssets.allSatisfy({ fileManager.fileExists(atPath: assetsDirectory.appendingPathComponent($0).path) }),
                  fileManager.fileExists(atPath: tokenizerDirectory.appendingPathComponent("tokenizer.json").path) else {
                return nil
            }
            return ImageToTextModelDirectories(
                vision: visionDirectory,
                decoder: decoderDirectory,
                assets: assetsDirectory,
                tokenizer: tokenizerDirectory
            )
        }
        let tokenizerURL = decoderDirectory.appendingPathComponent("tokenizer/tokenizer.json")
        guard hasModelBundle(in: visionDirectory),
              hasModelBundle(in: decoderDirectory),
              fileManager.fileExists(atPath: decoderDirectory.appendingPathComponent("metadata.json").path),
              fileManager.fileExists(atPath: tokenizerURL.path) else {
            return nil
        }
        return ImageToTextModelDirectories(vision: visionDirectory, decoder: decoderDirectory)
    }

    func miniCPMV46ModelDirectories(repositoryID: String) -> VisionLanguageModelDirectories? {
        guard VisionLanguageAdapter.adapter(for: repositoryID) == .miniCPMV46,
              isDownloaded(repositoryID: repositoryID) else { return nil }

        let root = installedDirectory(repositoryID: repositoryID)
        for variant in MiniCPMV46BundleVariant.all {
            let decoder = root.appendingPathComponent(variant.decoder, isDirectory: true)
            let vision = root.appendingPathComponent(variant.vision, isDirectory: true)
            let tokenizer = decoder.appendingPathComponent("tokenizer/tokenizer.json")
            guard hasModelBundle(in: decoder), hasModelBundle(in: vision),
                  fileManager.fileExists(atPath: tokenizer.path) else { continue }
            return VisionLanguageModelDirectories(vision: vision, decoder: decoder)
        }
        return nil
    }

    func speechRecognitionBundleURL(repositoryID: String) -> URL? {
        guard isDownloaded(repositoryID: repositoryID), let manifest = try? readManifest(repositoryID: repositoryID) else {
            return nil
        }
        let root = installedDirectory(repositoryID: repositoryID)
        if repositoryID.caseInsensitiveCompare("coreai-community/Parakeet-TDT-0.6B-CoreAI") == .orderedSame {
            let requiredPrefixes = ["parakeet_encoder", "parakeet_predict", "parakeet_joint"]
            let hasGraphs = requiredPrefixes.allSatisfy { prefix in
                manifest.files.contains {
                    $0.lowercased().contains(prefix)
                        && ($0.hasSuffix("main.mlirb") || $0.hasSuffix(".aimodel") || $0.hasSuffix(".aimodelc"))
                }
            }
            guard hasGraphs,
                  manifest.files.contains(where: { URL(fileURLWithPath: $0).lastPathComponent == "tokenizer.json" }) else {
                return nil
            }
            return root
        }
        let metadataURLs = manifest.files
            .filter { URL(fileURLWithPath: $0).lastPathComponent == "metadata.json" }
            .map { root.appending(path: $0) }
        for metadataURL in metadataURLs {
            guard let data = try? Data(contentsOf: metadataURL),
                  let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let kind = (metadata["kind"] as? String ?? "").lowercased()
            if kind.contains("speech") || kind.contains("parakeet") || kind.contains("whisper") {
                return metadataURL.deletingLastPathComponent()
            }
        }
        return nil
    }

    func objectDetectionModelURL(repositoryID: String) -> URL? {
        guard isDownloaded(repositoryID: repositoryID), let manifest = try? readManifest(repositoryID: repositoryID) else {
            return nil
        }
        let root = installedDirectory(repositoryID: repositoryID)
        let modelDirectories = Set(manifest.files.compactMap { path -> String? in
            guard path.lowercased().hasSuffix("/main.mlirb") || path.lowercased().hasSuffix("/main.hash") else {
                return nil
            }
            let graphDirectory = (path as NSString).deletingLastPathComponent
            guard graphDirectory.lowercased().hasSuffix(".aimodel") else { return nil }
            return graphDirectory
        })
        let preferredModel = modelDirectories.sorted {
            let lhsIsNano = $0.lowercased().contains("nano")
            let rhsIsNano = $1.lowercased().contains("nano")
            return lhsIsNano == rhsIsNano ? $0 < $1 : lhsIsNano
        }.first
        return preferredModel.map { root.appending(path: $0) }
    }

    func imageSegmentationBundleURL(repositoryID: String) -> URL? {
        guard isDownloaded(repositoryID: repositoryID), let manifest = try? readManifest(repositoryID: repositoryID) else {
            return nil
        }
        let root = installedDirectory(repositoryID: repositoryID)
        for relativePath in manifest.files where URL(fileURLWithPath: relativePath).lastPathComponent == "metadata.json" {
            let metadataURL = root.appending(path: relativePath)
            guard let data = try? Data(contentsOf: metadataURL),
                  let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  metadata["kind"] as? String == "segmenter" else { continue }
            return metadataURL.deletingLastPathComponent()
        }
        return nil
    }

    func flux2IOSModelDirectoryURL(repositoryID: String) -> URL? {
        guard repositoryID.caseInsensitiveCompare("grabbou/FLUX.2-klein-4B-CoreAI") == .orderedSame,
              isDownloaded(repositoryID: repositoryID) else {
            return nil
        }

        let directory = installedDirectory(repositoryID: repositoryID).appendingPathComponent("ios", isDirectory: true)
        let metadataURL = directory.appendingPathComponent("metadata.json")
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              metadata["kind"] as? String == "diffusion",
              let assets = metadata["assets"] as? [String: String],
              assets["transformer_512"] != nil,
              assets["text_encoder"] != nil,
              assets["vae_decoder_half"] != nil else {
            return nil
        }
        return directory
    }

    private func hasModelBundle(in directory: URL) -> Bool {
        guard let files = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return false }
        return files.contains { $0.lowercased().hasSuffix(".aimodel") || $0.lowercased().hasSuffix(".aimodelc") }
    }

    func installedRepositoryIDs() -> Set<String> {
        guard let directories = try? fileManager.contentsOfDirectory(
            at: storageRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return Set(directories.compactMap { directory in
            guard let manifest = try? JSONDecoder().decode(
                InstalledModelManifest.self,
                from: Data(contentsOf: directory.appendingPathComponent(".ondeviceai-model.json"))
            ), manifestIsComplete(manifest, in: directory) else {
                return nil
            }
            return manifest.repositoryID
        })
    }

    func download(
        repositoryID: String,
        displayName: String,
        progress: @escaping @MainActor @Sendable (Double?) -> Void
    ) async throws {
        if isDownloaded(repositoryID: repositoryID) { return }

        let metadata = try await fetchRepositoryMetadata(repositoryID: repositoryID)
        let filesToDownload = try selectedFiles(from: metadata.files, repositoryID: repositoryID)
        guard !filesToDownload.isEmpty else { throw ModelDownloadError.emptyRepository }

        try fileManager.createDirectory(at: storageRoot, withIntermediateDirectories: true)
        let stagingDirectory = storageRoot.appendingPathComponent(
            ".\(directoryName(for: repositoryID)).\(UUID().uuidString).partial",
            isDirectory: true
        )
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDirectory) }

        let expectedTotal = filesToDownload.reduce(Int64.zero) { $0 + max(0, $1.size ?? 0) }
        var completedBytes: Int64 = 0
        var completedFiles = 0

        for file in filesToDownload {
            try Task.checkCancellation()
            let destination = try fileURL(for: file.path, inside: stagingDirectory)
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let baseBytes = completedBytes
            let fileSize = max(0, file.size ?? 0)
            let baseFileCount = completedFiles
            let totalFileCount = filesToDownload.count
            let fileProgress: @MainActor @Sendable (Int64, Int64) -> Void = { written, responseExpected in
                let expected = fileSize > 0 ? fileSize : max(0, responseExpected)
                let fileFraction = expected > 0
                    ? min(1, Double(written) / Double(expected))
                    : 0
                let overall: Double
                if expectedTotal > 0 {
                    overall = min(1, Double(baseBytes + min(written, expected)) / Double(expectedTotal))
                } else {
                    overall = min(1, (Double(baseFileCount) + fileFraction) / Double(totalFileCount))
                }
                progress(overall)
            }

            let downloadURL = try fileURL(
                repositoryID: repositoryID,
                revision: metadata.revision,
                filename: file.path
            )
            try await fileDownloader.download(from: downloadURL, to: destination, progress: fileProgress)

            let attributes = try fileManager.attributesOfItem(atPath: destination.path)
            completedBytes += (attributes[.size] as? NSNumber)?.int64Value ?? fileSize
            completedFiles += 1
            let overall = expectedTotal > 0
                ? min(1, Double(completedBytes) / Double(expectedTotal))
                : Double(completedFiles) / Double(filesToDownload.count)
            await progress(overall)
        }

        let manifest = InstalledModelManifest(
            repositoryID: repositoryID,
            displayName: displayName,
            revision: metadata.revision,
            files: filesToDownload.map(\.path),
            installedAt: Date()
        )
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: stagingDirectory.appendingPathComponent(".ondeviceai-model.json"), options: .atomic)

        let installedDirectory = installedDirectory(repositoryID: repositoryID)
        if fileManager.fileExists(atPath: installedDirectory.path) {
            try fileManager.removeItem(at: installedDirectory)
        }
        try fileManager.moveItem(at: stagingDirectory, to: installedDirectory)
    }

    func downloadSize(repositoryID: String) async throws -> Int64 {
        let metadata = try await fetchRepositoryMetadata(repositoryID: repositoryID)
        let files = try selectedFiles(from: metadata.files, repositoryID: repositoryID)
        return files.reduce(Int64.zero) { $0 + max(0, $1.size ?? 0) }
    }

    private func fetchRepositoryMetadata(repositoryID: String) async throws -> HubRepositoryMetadata {
        let encodedID = repositoryID.split(separator: "/").map(String.init).map(encodePathComponent).joined(separator: "/")
        guard let url = URL(string: "https://huggingface.co/api/models/\(encodedID)?blobs=true") else {
            throw ModelDownloadError.invalidRepositoryID
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("OnDeviceAI/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelDownloadError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ModelDownloadError.httpStatus(httpResponse.statusCode)
        }
        let apiResponse = try JSONDecoder().decode(HubRepositoryAPIResponse.self, from: data)
        guard let revision = apiResponse.revision, !revision.isEmpty else {
            throw ModelDownloadError.missingRevision
        }
        let files = (apiResponse.files ?? []).compactMap { file -> HubRepositoryFile? in
            guard let path = file.path, !path.isEmpty, isSafeRelativePath(path) else { return nil }
            return HubRepositoryFile(path: path, size: file.size ?? file.lfs?.size)
        }
        return HubRepositoryMetadata(revision: revision, files: files)
    }

    private func selectedFiles(
        from files: [HubRepositoryFile],
        repositoryID: String
    ) throws -> [HubRepositoryFile] {
        if VisionLanguageAdapter.adapter(for: repositoryID) == .miniCPMV46 {
            // Prefer the bundle pair currently recommended by the model publisher,
            // while retaining the CoreAIKit preset pair for older repository revisions.
            guard let selectedVariant = MiniCPMV46BundleVariant.all.first(where: { variant in
                [variant.decoder, variant.vision].allSatisfy { prefix in
                    files.contains { $0.path == prefix || $0.path.hasPrefix(prefix + "/") }
                }
            }) else {
                throw ModelDownloadError.missingRequiredAssets
            }
            return files.filter { file in
                [selectedVariant.decoder, selectedVariant.vision].contains { prefix in
                    file.path == prefix || file.path.hasPrefix(prefix + "/")
                }
            }
        }

        if repositoryID.caseInsensitiveCompare("coreai-community/Audio8-TTS-Preview-0.6b-CoreAI") == .orderedSame {
            let requiredPaths = [
                "audio8_dualar_int8_cl2048_w32.aimodel",
                "audio8_codec_decoder_fp16_t160.aimodel",
                "tokenizer"
            ]
            let containsPath = { (prefix: String) in
                files.contains { $0.path == prefix || $0.path.hasPrefix(prefix + "/") }
            }
            guard requiredPaths.allSatisfy(containsPath) else {
                throw ModelDownloadError.missingRequiredAssets
            }
            return files.filter { file in
                requiredPaths.contains { file.path == $0 || file.path.hasPrefix($0 + "/") }
            }
        }

        let iosDirectories = Set(files.compactMap { file -> String? in
            guard let directory = platformDirectory(in: file.path), directory.isIOS else { return nil }
            return directory.path
        })
        guard !iosDirectories.isEmpty else {
            let hasMacOSDirectories = files.contains {
                guard let directory = platformDirectory(in: $0.path) else { return false }
                return !directory.isIOS
            }
            return hasMacOSDirectories
                ? files.filter { platformDirectory(in: $0.path).map(\.isIOS) == nil }
                : files
        }

        let genericIOSDirectories = iosDirectories.filter {
            URL(fileURLWithPath: $0).lastPathComponent.caseInsensitiveCompare("ios") == .orderedSame
        }
        let selectedIOSDirectories = genericIOSDirectories.isEmpty ? iosDirectories : genericIOSDirectories
        let supportedSharedDirectories: Set<String> = ["tokenizer", "glue", "host", "assets"]
        let supportedRootExtensions: Set<String> = ["json", "md", "txt", "license"]

        return files.filter { file in
            if selectedIOSDirectories.contains(where: { file.path == $0 || file.path.hasPrefix($0 + "/") }) {
                return true
            }
            if platformDirectory(in: file.path) != nil { return false }

            let components = file.path.split(separator: "/").map(String.init)
            if let first = components.first?.lowercased(), supportedSharedDirectories.contains(first) {
                return true
            }
            guard components.count == 1 else { return false }
            let filename = components[0].lowercased()
            if ["tokenizer", "vocab", "merges", "special_tokens", "added_tokens"].contains(where: {
                filename.hasPrefix($0)
            }) {
                return true
            }
            return supportedRootExtensions.contains(URL(fileURLWithPath: filename).pathExtension)
        }

    }

    private func platformDirectory(in path: String) -> (path: String, isIOS: Bool)? {
        let components = path.split(separator: "/").map(String.init)
        for (index, component) in components.enumerated() {
            let value = component.lowercased()
            let isIOS = value == "ios" || value.hasPrefix("ios-") || value.hasPrefix("ios_")
                || value == "iphone" || value.hasPrefix("iphone-") || value.hasPrefix("iphone_")
            let isMacOS = value == "macos" || value.hasPrefix("macos-") || value.hasPrefix("macos_")
                || value == "mac" || value.hasPrefix("mac-") || value.hasPrefix("mac_")
            if isIOS || isMacOS {
                return (components.prefix(index + 1).joined(separator: "/"), isIOS)
            }
        }
        return nil
    }

    private func fileURL(repositoryID: String, revision: String, filename: String) throws -> URL {
        let components = repositoryID.split(separator: "/").map(String.init)
            + ["resolve", revision]
            + filename.split(separator: "/").map(String.init)
        let encodedPath = components.map(encodePathComponent).joined(separator: "/")
        guard let url = URL(string: "https://huggingface.co/\(encodedPath)") else {
            throw ModelDownloadError.invalidFileURL(filename)
        }
        return url
    }

    private func fileURL(for relativePath: String, inside directory: URL) throws -> URL {
        guard isSafeRelativePath(relativePath) else { throw ModelDownloadError.invalidFilePath(relativePath) }
        let destination = directory.appending(path: relativePath).standardizedFileURL
        guard destination.path.hasPrefix(directory.standardizedFileURL.path + "/") else {
            throw ModelDownloadError.invalidFilePath(relativePath)
        }
        return destination
    }

    private func isSafeRelativePath(_ path: String) -> Bool {
        !path.hasPrefix("/") && !path.split(separator: "/").contains { $0 == "." || $0 == ".." }
    }

    private func encodePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func readManifest(repositoryID: String) throws -> InstalledModelManifest {
        let manifestURL = installedDirectory(repositoryID: repositoryID).appendingPathComponent(".ondeviceai-model.json")
        return try JSONDecoder().decode(InstalledModelManifest.self, from: Data(contentsOf: manifestURL))
    }

    private func manifestIsComplete(_ manifest: InstalledModelManifest, in directory: URL) -> Bool {
        !manifest.files.isEmpty && manifest.files.allSatisfy { relativePath in
            guard isSafeRelativePath(relativePath) else { return false }
            let fileURL = directory.appending(path: relativePath).standardizedFileURL
            return fileURL.path.hasPrefix(directory.standardizedFileURL.path + "/")
                && fileManager.fileExists(atPath: fileURL.path)
        }
    }

    private func installedDirectory(repositoryID: String) -> URL {
        storageRoot.appendingPathComponent(directoryName(for: repositoryID), isDirectory: true)
    }

    private func directoryName(for repositoryID: String) -> String {
        repositoryID.replacingOccurrences(of: "/", with: "--")
    }
}

struct ImageToTextModelDirectories {
    let vision: URL
    let decoder: URL
    let assets: URL?
    let tokenizer: URL?

    init(vision: URL, decoder: URL, assets: URL? = nil, tokenizer: URL? = nil) {
        self.vision = vision
        self.decoder = decoder
        self.assets = assets
        self.tokenizer = tokenizer
    }
}

struct VisionLanguageModelDirectories {
    let vision: URL
    let decoder: URL
}

private struct HubRepositoryAPIResponse: Decodable {
    let revision: String?
    let files: [HubRepositoryFileMetadata]?

    enum CodingKeys: String, CodingKey {
        case revision = "sha"
        case files = "siblings"
    }
}

private struct HubRepositoryFileMetadata: Decodable {
    let path: String?
    let size: Int64?
    let lfs: HubLFSMetadata?

    enum CodingKeys: String, CodingKey {
        case path = "rfilename"
        case size
        case lfs
    }
}

private struct HubLFSMetadata: Decodable {
    let size: Int64?
}

private struct HubRepositoryMetadata {
    let revision: String
    let files: [HubRepositoryFile]
}

private struct HubRepositoryFile {
    let path: String
    let size: Int64?
}

private struct InstalledModelManifest: Codable {
    let repositoryID: String
    let displayName: String
    let revision: String
    let files: [String]
    let installedAt: Date
}

private enum ModelDownloadError: LocalizedError {
    case emptyRepository
    case invalidRepositoryID
    case invalidResponse
    case httpStatus(Int)
    case missingRevision
    case missingRequiredAssets
    case invalidFileURL(String)
    case invalidFilePath(String)

    var errorDescription: String? {
        switch self {
        case .emptyRepository:
            "This Hugging Face repository doesn’t contain downloadable files."
        case .invalidRepositoryID:
            "The Hugging Face repository ID is invalid."
        case .invalidResponse:
            "Hugging Face returned an invalid model response."
        case .httpStatus(let status):
            "Hugging Face could not provide this model (HTTP \(status))."
        case .missingRevision:
            "Hugging Face did not provide a revision for this model."
        case .missingRequiredAssets:
            "This Audio8-TTS repository is missing the model, codec, or tokenizer files required for speech generation."
        case .invalidFileURL(let filename):
            "Couldn’t create a download URL for \(filename)."
        case .invalidFilePath(let path):
            "The repository contains an invalid file path: \(path)."
        }
    }
}

private final class ModelFileDownloadSession: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private final class PendingDownload {
        let destination: URL
        let continuation: CheckedContinuation<Void, Error>
        let progress: @MainActor @Sendable (Int64, Int64) -> Void
        var fileError: Error?
        var receivedFile = false

        init(
            destination: URL,
            continuation: CheckedContinuation<Void, Error>,
            progress: @escaping @MainActor @Sendable (Int64, Int64) -> Void
        ) {
            self.destination = destination
            self.continuation = continuation
            self.progress = progress
        }
    }

    private let lock = NSLock()
    private var pending: [Int: PendingDownload] = [:]
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    func download(
        from url: URL,
        to destination: URL,
        progress: @escaping @MainActor @Sendable (Int64, Int64) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url)
            lock.lock()
            pending[task.taskIdentifier] = PendingDownload(
                destination: destination,
                continuation: continuation,
                progress: progress
            )
            lock.unlock()
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        lock.lock()
        let callback = pending[downloadTask.taskIdentifier]?.progress
        lock.unlock()
        guard let callback else { return }
        Task { @MainActor in callback(totalBytesWritten, totalBytesExpectedToWrite) }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let statusCode = (downloadTask.response as? HTTPURLResponse)?.statusCode
        var result: Result<Void, Error> = .success(())
        if let statusCode, !(200..<300).contains(statusCode) {
            result = .failure(ModelDownloadError.httpStatus(statusCode))
        } else {
            do {
                lock.lock()
                let destination = pending[downloadTask.taskIdentifier]?.destination
                lock.unlock()
                guard let destination else { throw ModelDownloadError.invalidResponse }
                try FileManager.default.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: location, to: destination)
            } catch {
                result = .failure(error)
            }
        }

        lock.lock()
        if let item = pending[downloadTask.taskIdentifier] {
            switch result {
            case .success:
                item.receivedFile = true
            case .failure(let error):
                item.fileError = error
            }
        }
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let item = pending.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        guard let item else { return }

        if let error {
            item.continuation.resume(throwing: error)
        } else if let fileError = item.fileError {
            item.continuation.resume(throwing: fileError)
        } else if item.receivedFile {
            item.continuation.resume()
        } else {
            item.continuation.resume(throwing: ModelDownloadError.invalidResponse)
        }
    }
}
