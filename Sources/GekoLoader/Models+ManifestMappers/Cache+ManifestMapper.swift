import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

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

extension Cache {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        self.path = try self.path.map { try generatorPaths.resolve(path: $0) }

        for i in 0 ..< profiles.count {
            profiles[i].options.swiftModuleCacheEnabled =
                Environment.shared.swiftModuleCacheEnabled ?? profiles[i].options.swiftModuleCacheEnabled
        }
    }
}
