import GekoGraph
import GekoPlugin
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.PluginConfigManifest

public final class MockPluginsFacade: PluginsFacading {
    public init() {}

    public var loadPluginsStub: (Config) -> Plugins = { _ in .none }
    public func loadPlugins(using config: Config) throws -> Plugins {
        loadPluginsStub(config)
    }

    public var fetchRemotePluginsStub: ((Config) throws -> Void)?
    public func fetchRemotePlugins(using config: Config) throws {
        try fetchRemotePluginsStub?(config)
    }
    
    public var executablePluginsStub: ((Config) throws -> [ExecutablePluginGeko])?
    public func executablePlugins(using config: Config) throws -> [ExecutablePluginGeko] {
        try executablePluginsStub?(config) ?? []
    }
    
    public var workspaceMapperPluginsStub: ((Config) throws -> [WorkspaceMapperPluginPath])?
    public func workspaceMapperPlugins(using config: Config) throws -> [WorkspaceMapperPluginPath] {
        try workspaceMapperPluginsStub?(config) ?? []
    }
}
