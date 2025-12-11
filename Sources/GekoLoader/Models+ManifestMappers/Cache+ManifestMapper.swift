import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoSupport

enum CacheProfileError: FatalError, Equatable {
    case invalidVersion(string: String)

    var description: String {
        switch self {
        case let .invalidVersion(string):
            return "Invalid version string \(string)"
        }
    }

    var type: ErrorType {
        switch self {
        case .invalidVersion:
            return .abort
        }
    }
}

extension GekoGraph.Cache {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        self.path = try self.path.map { try generatorPaths.resolve(path: $0) }

        for i in 0 ..< profiles.count {
            profiles[i].options.swiftModuleCacheEnabled =
                Environment.shared.swiftModuleCacheEnabled ?? profiles[i].options.swiftModuleCacheEnabled
        }
    }
}
