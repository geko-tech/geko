import ProjectDescription
import GekoCore
import GekoGraph

public protocol CacheArtifactBuilding {
    /// Builds a given target and outputs the cacheable artifact into the given directory.
    ///
    /// - Parameters:
    ///   - projectTarget: Build target whether .xcworkspace or .xcodeproj
    ///   - configuration: The configuration that will be used when compiling the given target.
    ///   - osVersion: The specific version of the OS that will be used when compiling the given target.
    ///   - deviceName: The specific device that will be used when compiling the given target.
    ///   - into: The directory into which the output artifacts will be copied.
    func build(
        graph: Graph,
        scheme: Scheme,
        projectTarget: XcodeBuildTarget,
        derivedDataPath: AbsolutePath?,
        rosseta: Bool,
        configuration: String,
        osVersion: Version?,
        deviceName: String?,
        into outputDirectory: AbsolutePath
    ) async throws
}

extension CacheArtifactBuilding {
    public func platform(scheme: Scheme) -> Platform {
        Platform.allCases.first { scheme.name.hasSuffix($0.caseValue) }!
    }
}
