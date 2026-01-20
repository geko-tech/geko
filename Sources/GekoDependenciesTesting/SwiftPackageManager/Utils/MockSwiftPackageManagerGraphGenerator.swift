import GekoCore
import GekoGraph
import ProjectDescription

@testable import GekoDependencies

public final class MockSwiftPackageManagerGraphGenerator: SwiftPackageManagerGraphGenerating {
    public init() {}

    var invokedGenerate = false
    var generateStub: (
        (
            AbsolutePath,
            [String: Product],
            Settings,
            [String: Settings],
            Version?,
            [String: ProjectDescription.Project.Options],
            [String: String?]
        ) throws -> GekoCore.DependenciesGraph
    )?

    public func generate(
        at path: AbsolutePath,
        productTypes: [String: Product],
        baseSettings: Settings,
        targetSettings: [String: Settings],
        swiftToolsVersion: Version?,
        projectOptions: [String: ProjectDescription.Project.Options],
        resolvedDependenciesVersions: [String: String?]
    ) throws -> GekoCore.DependenciesGraph {
        invokedGenerate = true
        return try generateStub?(
            path,
            productTypes,
            baseSettings,
            targetSettings,
            swiftToolsVersion,
            projectOptions,
            resolvedDependenciesVersions
        ) ?? .test()
    }
}
