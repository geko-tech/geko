import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport

enum CloudManifestMapperError: FatalError {
    /// Thrown when the cloud URL is invalid.
    case invalidCloudURL(String)

    /// Error type.
    var type: ErrorType {
        switch self {
        case .invalidCloudURL: return .abort
        }
    }

    /// Error description.
    var description: String {
        switch self {
        case let .invalidCloudURL(url):
            return "The cloud URL '\(url)' is not a valid URL"
        }
    }
}

extension GekoGraph.Cloud {
    func validateUrl() throws {
        if URL(string: url) == nil {
            throw CloudManifestMapperError.invalidCloudURL(url)
        }
    }
}
