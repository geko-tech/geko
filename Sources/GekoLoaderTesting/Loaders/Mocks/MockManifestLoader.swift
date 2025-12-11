import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.Plugin
import struct GekoGraph.Plugins
import GekoSupport
@testable import GekoLoader
@testable import GekoSupportTesting

public final class MockManifestLoader: ManifestLoading {
    public var loadProjectCount: UInt = 0
    public var loadProjectStub: ((AbsolutePath) throws -> Project)?

    public var loadWorkspaceCount: UInt = 0
    public var loadWorkspaceStub: ((AbsolutePath) throws -> Workspace)?

    public var manifestsAtCount: UInt = 0
    public var manifestsAtStub: ((AbsolutePath) -> Set<Manifest>)?

    public var manifestPathCount: UInt = 0
    public var manifestPathStub: ((AbsolutePath, Manifest) throws -> AbsolutePath)?

    public var loadConfigCount: UInt = 0
    public var loadConfigStub: ((AbsolutePath) throws -> Config)?

    public var loadTemplateCount: UInt = 0
    public var loadTemplateStub: ((AbsolutePath) throws -> Template)?

    public var loadDependenciesCount: UInt = 0
    public var loadDependenciesStub: ((AbsolutePath) throws -> Dependencies)?

    public var loadPackageSettingsCount: UInt = 0
    public var loadPackageSettingsStub: ((AbsolutePath) throws -> PackageSettings)?

    public var loadPluginCount: UInt = 0
    public var loadPluginStub: ((AbsolutePath) throws -> Plugin)?

    public init() {}

    public func loadProject(at path: AbsolutePath) throws -> Project {
        try loadProjectStub?(path) ?? Project.manifestTest()
    }

    public func loadWorkspace(at path: AbsolutePath) throws -> Workspace {
        try loadWorkspaceStub?(path) ?? Workspace.manifestTest()
    }

    public func manifests(at path: AbsolutePath) -> Set<Manifest> {
        manifestsAtCount += 1
        return manifestsAtStub?(path) ?? Set()
    }

    public func validateHasProjectOrWorkspaceManifest(at path: AbsolutePath) throws {
        let manifests = manifests(at: path)
        guard manifests.contains(.workspace) || manifests.contains(.project) else {
            throw ManifestLoaderError.manifestNotFound(path)
        }
    }

    func manifestPath(at path: AbsolutePath, manifest: Manifest) throws -> AbsolutePath {
        manifestPathCount += 1
        return try manifestPathStub?(path, manifest) ?? TemporaryDirectory(removeTreeOnDeinit: true).path
    }

    public func loadConfig(at path: AbsolutePath) throws -> Config {
        loadConfigCount += 1
        return try loadConfigStub?(path) ?? Config.manifestTest()
    }

    public func loadTemplate(at path: AbsolutePath) throws -> Template {
        loadTemplateCount += 1
        return try loadTemplateStub?(path) ?? Template.manifestTest()
    }

    public func loadDependencies(at path: AbsolutePath) throws -> Dependencies {
        loadDependenciesCount += 1
        return try loadDependenciesStub?(path) ?? Dependencies.manifestTest()
    }

    public func loadPackageSettings(at path: AbsolutePath) throws -> PackageSettings {
        loadPackageSettingsCount += 1
        return try loadPackageSettingsStub?(path) ?? .manifestTest()
    }

    public func loadPlugin(at path: AbsolutePath) throws -> Plugin {
        loadPluginCount += 1
        return try loadPluginStub?(path) ?? Plugin(name: "Plugin")
    }

    public var taskLoadArgumentsStub: ((AbsolutePath) throws -> [String])?
    public func taskLoadArguments(at path: AbsolutePath) throws -> [String] {
        try taskLoadArgumentsStub?(path) ?? []
    }

    public var registerPluginsCount: UInt = 0
    public var registerPluginsStub: ((Plugins) throws -> Void)?
    public func register(plugins: Plugins) throws {
        registerPluginsCount += 1
        try registerPluginsStub?(plugins)
    }

    public var cleanupOldManifestsCount: UInt = 0
    public var cleanupOldManifestsStub: (() throws -> [SideEffectDescriptor])?
    public func cleanupOldManifests() throws -> [SideEffectDescriptor] {
        cleanupOldManifestsCount += 1
        return try cleanupOldManifestsStub?() ?? []
    }
}
