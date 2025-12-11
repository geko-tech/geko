import Foundation

/// An enum that represents the type of output that the caching feature can work with.
public enum CacheOutputType: String, Equatable {
    /// Frameworks with selected destination
    case framework

    /// XCFrameworks with selected destination
    case xcframework

    public var productExtension: String {
        switch self {
        case .framework:
            return "framework"
        case .xcframework:
            return "xcframework"
        }
    }
}
