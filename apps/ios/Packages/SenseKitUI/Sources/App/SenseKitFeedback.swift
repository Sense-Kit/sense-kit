import Foundation

public enum SenseKitFeedbackStyle: String, Codable, Equatable, Sendable {
    case success
    case error
}

public struct SenseKitFeedback: Codable, Equatable, Sendable {
    public let style: SenseKitFeedbackStyle
    public let message: String

    public init(style: SenseKitFeedbackStyle, message: String) {
        self.style = style
        self.message = message
    }
}
