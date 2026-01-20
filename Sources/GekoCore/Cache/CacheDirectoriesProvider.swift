import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol CacheDirectoriesProviding {
    /// Returns the cache directory for a cache category
    func cacheDirectory(for category: CacheCategory) -> AbsolutePath
}

public final class CacheDirectoriesProvider: CacheDirectoriesProviding {
    public let cacheDirectory: AbsolutePath
    // swiftlint:disable:next force_try
    private static let defaultDirectory = try! AbsolutePath(validatingAbsolutePath: URL(fileURLWithPath: NSHomeDirectory()).path)
        .appending(component: ".geko")
    private static var forcedCacheDirectory: AbsolutePath? {
        directoryFromEnv(variable: Constants.EnvironmentVariables.forceConfigCacheDirectory)
    }
    private static var forcedBuildCacheDirectory: AbsolutePath? {
        directoryFromEnv(variable: Constants.EnvironmentVariables.forceBuildCacheDirectory)
    }
    private static func directoryFromEnv(variable: String) -> AbsolutePath? {
        if let value = Self.cachedEnvs.wrappedValue[variable] {
            return value
        }
        return Self.cachedEnvs.modify({ cache in
            let value = ProcessInfo.processInfo.environment[variable]
                .map { try! AbsolutePath(validatingAbsolutePath: $0) } // swiftlint:disable:this force_try
            cache[variable] = value
            return value
        })
    }
    private static var cachedEnvs: Atomic<[String: AbsolutePath?]> = .init(wrappedValue: [:])
    
    internal static func resetCachedEnvironments() {
        cachedEnvs.wrappedValue = [:]
    }

    public init(config: Config?) {
        if let cacheDirectory = config?.cache?.path {
            self.cacheDirectory = cacheDirectory
        } else {
            cacheDirectory = CacheDirectoriesProvider.defaultDirectory.appending(component: "Cache")
        }
    }

    public func cacheDirectory(for category: CacheCategory) -> AbsolutePath {
        if let forcedCacheDirectory = forcedCacheDirectory(for: category) {
            forcedCacheDirectory
        } else {
            (Self.forcedCacheDirectory ?? cacheDirectory).appending(component: category.directoryName)
        }
    }
    
    private func forcedCacheDirectory(for category: CacheCategory) -> AbsolutePath? {
        switch category {
        case .plugins, .tests, .generatedAutomationProjects, .projectDescriptionHelpers, .manifests:
            nil
        case .builds:
            Self.forcedBuildCacheDirectory
        }
    }
}
