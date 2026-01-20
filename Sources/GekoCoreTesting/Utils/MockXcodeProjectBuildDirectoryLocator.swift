import GekoCore
import GekoGraph
import ProjectDescription

public final class MockXcodeProjectBuildDirectoryLocator: XcodeProjectBuildDirectoryLocating {
    public init() {}

    // swiftlint:disable:next type_name
    enum MockXcodeProjectBuildDirectoryLocatorError: Error {
        case noStub
    }

    public var locateStub: ((Platform, AbsolutePath, AbsolutePath?, String, CacheFrameworkDestination) throws -> AbsolutePath)?
    public func locate(
        platform: Platform,
        projectPath: AbsolutePath,
        derivedDataPath: AbsolutePath?,
        configuration: String,
        destination: CacheFrameworkDestination
    ) throws -> AbsolutePath {
        guard let stub = locateStub else {
            throw MockXcodeProjectBuildDirectoryLocatorError.noStub
        }
        return try stub(platform, projectPath, derivedDataPath, configuration, destination)
    }
    
    public var locateNoIndexStub: ((Platform, AbsolutePath, AbsolutePath?, String, CacheFrameworkDestination) throws -> AbsolutePath)?
    public func locateNoIndex(
        platform: Platform,
        projectPath: AbsolutePath,
        derivedDataPath: AbsolutePath?,
        configuration: String,
        destination: GekoCore.CacheFrameworkDestination
    ) throws -> AbsolutePath {
        guard let stub = locateStub else {
            throw MockXcodeProjectBuildDirectoryLocatorError.noStub
        }
        return try stub(platform, projectPath, derivedDataPath, configuration, destination)
    }
}
