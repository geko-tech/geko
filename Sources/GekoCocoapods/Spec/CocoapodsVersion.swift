import Foundation
import GekoSupport
import ProjectDescription

public typealias CocoapodsVersion = ProjectDescription.PackageVersion

public enum CocoapodsVersionError: FatalError {
    case invalidVersion(String, specName: String, context: String = "")

    public var description: String {
        switch self {
        case let .invalidVersion(versionString, specName, context):
            return "Failed to parse version string \"\(versionString)\" for spec \"\(specName)\" \(context)"
        }
    }

    public var type: ErrorType {
        return .abort
    }
}
