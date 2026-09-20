import ProjectDescription
@testable import GekoSupport

public final class MockPackageInfoMapping: PackageInfoMapping {
    public init() {}

    public var invokedResolveExternalDependencies = false
    public var resolveExternalDependenciesStub: ((
        AbsolutePath,
        [String: PackageInfo],
        [String: AbsolutePath],
        [String: [String: AbsolutePath]],
        [String: [String: String]]
    ) throws -> [String: [ProjectDescription.TargetDependency]])?
    public func resolveExternalDependencies(
        path: AbsolutePath,
        packageInfos: [String: PackageInfo],
        packageToFolder: [String: AbsolutePath],
        packageToTargetsToArtifactPaths: [String: [String: AbsolutePath]],
        packageModuleAliases: [String: [String: String]]
    ) throws -> [String: [ProjectDescription.TargetDependency]] {
        invokedResolveExternalDependencies = true
        return try resolveExternalDependenciesStub?(
            path,
            packageInfos,
            packageToFolder,
            packageToTargetsToArtifactPaths,
            packageModuleAliases
        ) ?? [:]
    }

    public var invokedMap = false
    public var mapStub: ((
        PackageInfo,
        AbsolutePath,
        [String: Product],
        Settings,
        [String: Settings],
        ProjectDescription.Project.Options?,
        [String: AbsolutePath],
        [String: [String: String]],
        Set<String>,
        Bool
    ) throws -> ProjectDescription.Project?)?
    public func map(
        packageInfo: PackageInfo,
        path: AbsolutePath,
        productTypes: [String: Product],
        baseSettings: Settings,
        targetSettings: [String: Settings],
        projectOptions: ProjectDescription.Project.Options?,
        targetsToArtifactPaths: [String: AbsolutePath],
        packageModuleAliases: [String: [String: String]],
        enabledTraits: Set<String>,
        isLocal: Bool
    ) throws -> ProjectDescription.Project? {
        invokedMap = true
        return try mapStub?(
            packageInfo,
            path,
            productTypes,
            baseSettings,
            targetSettings,
            projectOptions,
            targetsToArtifactPaths,
            packageModuleAliases,
            enabledTraits,
            isLocal
        ) ?? nil
    }
}