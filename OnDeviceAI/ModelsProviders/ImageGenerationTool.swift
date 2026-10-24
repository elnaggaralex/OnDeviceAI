import Foundation
import FoundationModels
import ImagePlayground

@Generable
enum RequestedImageStyle: Equatable, Sendable {
    case automatic
    case animation
    case illustration
    case sketch
    case emoji
}

struct ImageGenerationRequest: Equatable, Sendable {
    let description: String
    let style: RequestedImageStyle
}

@MainActor
final class ImagePlaygroundProvider {
    var onGenerationRequest: ((ImageGenerationRequest) -> Void)?
    private var didHandleRequest = false

    func prepareForNewRequest() {
        didHandleRequest = false
    }

    func present(_ request: ImageGenerationRequest) -> Bool {
        guard !didHandleRequest else { return false }
        didHandleRequest = true
        onGenerationRequest?(request)
        return true
    }
}

struct GenerateImageTool: Tool {
    let imagePlaygroundProvider: ImagePlaygroundProvider
    let name = "generateImage"
    let description = "Open Apple Image Playground to create an image from the user's request. Use this when the user asks to create, generate, draw, or illustrate an image."

    @Generable
    struct Arguments: Sendable {
        @Guide(description: "A vivid, concise visual description for Image Playground. Include the subject, setting, composition, and visual details requested by the user. Do not describe the image as already created.")
        var description: String

        @Guide(description: "Choose the closest Image Playground style requested by the user. Use automatic for styles such as photorealistic or when no style is specified.")
        var style: RequestedImageStyle
    }

    func call(arguments: Arguments) async throws -> String {
        let description = arguments.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else {
            return "Image Playground was not opened because no image description was provided."
        }
        guard ImagePlaygroundViewController.isAvailable else {
            return "Image Playground is unavailable on this device right now. Do not claim an image was created."
        }

        let request = ImageGenerationRequest(description: description, style: arguments.style)
        let didPresent = await imagePlaygroundProvider.present(request)
        return didPresent
            ? "Image Playground is open with the requested image description. Let the user finish creating the image, then provide a brief confirmation. Do not call generateImage again."
            : "Image Playground has already been opened for this request. Do not call generateImage again."
    }
}

extension RequestedImageStyle {
    var playgroundStyle: ImagePlaygroundStyle {
        switch self {
        case .automatic: .any
        case .animation: .animation
        case .illustration: .illustration
        case .sketch: .sketch
        case .emoji: .emoji
        }
    }
}
