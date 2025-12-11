import Foundation
import ProjectDescription

@testable import GekoPlugin

public final class MockGekoPluginLoader: GekoPluginLoading {

    public init() {}

    public var loadGekoPluginCounter: Int = 0
    public var loadGekoPluginStubs: [(WorkspaceMapperPluginPath) throws -> GekoPlugin] = []

    public func loadGekoPlugin(mapperPath: WorkspaceMapperPluginPath) throws -> GekoPlugin {
        loadGekoPluginCounter += 1
        return try loadGekoPluginStubs[loadGekoPluginCounter - 1](mapperPath)
    }
}
