import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoSupport

@testable import GekoLoader

public final class MockProjectDescriptionHelpersBuilder: ProjectDescriptionHelpersBuilding {
    public var buildStub: (
        AbsolutePath, ProjectDescriptionSearchPaths, [ProjectDescriptionHelpersPlugin]
    ) -> [ProjectDescriptionHelpersModule] = { _, _, _ in [] }
    public func build(
        at path: AbsolutePath,
        projectDescriptionSearchPaths: ProjectDescriptionSearchPaths,
        projectDescriptionHelperPlugins: [ProjectDescriptionHelpersPlugin]
    ) throws -> [ProjectDescriptionHelpersModule] {
        buildStub(path, projectDescriptionSearchPaths, projectDescriptionHelperPlugins)
    }

    public var buildPluginsStub: (
        AbsolutePath, ProjectDescriptionSearchPaths, [ProjectDescriptionHelpersPlugin]
    ) -> [ProjectDescriptionHelpersModule] = { _, _, _ in [] }
    public func buildPlugins(
        at path: AbsolutePath,
        projectDescriptionSearchPaths: ProjectDescriptionSearchPaths,
        projectDescriptionHelperPlugins: [ProjectDescriptionHelpersPlugin]
    ) throws -> [ProjectDescriptionHelpersModule] {
        buildPluginsStub(path, projectDescriptionSearchPaths, projectDescriptionHelperPlugins)
    }
}
