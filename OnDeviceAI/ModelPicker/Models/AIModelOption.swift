import Foundation

enum AIModelCategory: Equatable {
    case text
    case vision
    case audio
    case other

    init(task: String) {
        if task.contains("audio") || task.contains("speech") || task.contains("voice") {
            self = .audio
        } else if task.contains("image") || task.contains("vision") || task.contains("visual")
                    || task.contains("detection") || task.contains("depth") || task.contains("video")
                    || task.contains("3d") {
            self = .vision
        } else if task.contains("text") || task.contains("language") || task.contains("embedding")
                    || task.contains("token-classification") || task.contains("classification")
                    || task.contains("ranking") || task.contains("retrieval") || task.contains("similarity")
                    || task.contains("feature") {
            self = .text
        } else {
            self = .other
        }
    }
}

enum AIModelExecutionCapability: Equatable {
    case textGeneration
    case visionLanguage(VisionLanguageAdapter)
    case imageToText(ImageToTextAdapter)
    case textToSpeech
    case speechToText
    case objectDetection
    case imageSegmentation
    case unsupported

    init(task: String, repositoryID: String) {
        let normalizedTask = task
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")

        if normalizedTask.contains("text-to-speech") || normalizedTask.contains("text-to-audio") {
            self = .textToSpeech
        } else if normalizedTask.contains("automatic-speech-recognition") || normalizedTask.contains("speech-to-text") {
            self = .speechToText
        } else if normalizedTask.contains("object-detection") {
            self = .objectDetection
        } else if normalizedTask.contains("mask-generation") || normalizedTask.contains("image-segmentation") {
            self = .imageSegmentation
        } else if normalizedTask.contains("image-text-to-text") {
            if let adapter = VisionLanguageAdapter.adapter(for: repositoryID) {
                self = .visionLanguage(adapter)
            } else {
                self = .unsupported
            }
        } else if normalizedTask.contains("image-to-text") || normalizedTask.contains("ocr") {
            if let adapter = ImageToTextAdapter.adapter(for: repositoryID) {
                self = .imageToText(adapter)
            } else {
                self = .unsupported
            }
        } else if normalizedTask.contains("text-generation") || normalizedTask == "text-generation" {
            self = .textGeneration
        } else {
            self = .unsupported
        }
    }
}

enum VisionLanguageAdapter: Equatable {
    case miniCPMV46

    static func adapter(for repositoryID: String) -> VisionLanguageAdapter? {
        switch repositoryID.lowercased() {
        case "coreai-community/minicpm-v-4.6-coreai", "mlboydaisuke/minicpm-v-4.6-coreai":
            .miniCPMV46
        default:
            nil
        }
    }
}

enum ImageToTextAdapter: Equatable {
    case glmOCR
    case unlimitedOCR

    static func adapter(for repositoryID: String) -> ImageToTextAdapter? {
        switch repositoryID.lowercased() {
        case "coreai-community/glm-ocr-coreai", "mlboydaisuke/glm-ocr-coreai": .glmOCR
        case "coreai-community/unlimited-ocr-coreai": .unlimitedOCR
        default: nil
        }
    }
}

struct AIModelOption: Identifiable {
    var id: String { repositoryID }
    let repositoryID: String
    let name: String
    let task: String
    let license: String
    let downloads: Int
    let likes: Int
    let category: AIModelCategory

    var executionCapability: AIModelExecutionCapability {
        AIModelExecutionCapability(task: task, repositoryID: repositoryID)
    }

    var icon: String {
        switch category {
        case .text: "text.alignleft"
        case .vision: "viewfinder"
        case .audio: "waveform"
        case .other: "cpu"
        }
    }

    init(
        repositoryID: String,
        name: String,
        task: String,
        license: String,
        downloads: Int,
        likes: Int,
        category: AIModelCategory
    ) {
        self.repositoryID = repositoryID
        self.name = name
        self.task = task
        self.license = license
        self.downloads = downloads
        self.likes = likes
        self.category = category
    }
}
