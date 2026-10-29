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

struct AIModelOption: Identifiable {
    var id: String { repositoryID }
    let repositoryID: String
    let name: String
    let task: String
    let license: String
    let downloads: Int
    let likes: Int
    let category: AIModelCategory

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
