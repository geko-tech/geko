import Foundation
import ProjectDescription

@testable import GekoPlugin

public final class MockGekoPluginLoader: GekoPluginLoading {

    public init() {}

    public var loadGekoPluginCounter: Int = 0
    public var loadGekoPluginStubs: [(WorkspaceMapperPluginPath, Workspace.GenerationOptions) async throws -> GekoPlugin] = []

    public func loadGekoPlugin(mapperPath: WorkspaceMapperPluginPath, generationOptions: Workspace.GenerationOptions) async throws -> GekoPlugin {
        loadGekoPluginCounter += 1
        return try await loadGekoPluginStubs[loadGekoPluginCounter - 1](mapperPath, generationOptions)
    }
}
