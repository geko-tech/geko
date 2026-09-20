import ProjectDescription

public protocol PackageInfoMapping {

    /// Resolves external SwiftPackageManager dependencies.
    /// - Parameters:
    ///   - path: The path to the directory that contains the `checkouts` directory where `SwiftPackageManager` installed
    ///   - packageInfos: All available `PackageInfo`s
    ///   - packageToFolder: Mapping from a package name to its local folder
    ///   - packageToTargetsToArtifactPaths: Mapping from a package name its targets' names to artifacts' paths
    ///   - packageModuleAliases: Package module aliases
    /// - Returns: Mapped project
    func resolveExternalDependencies(
        path: AbsolutePath,
        packageInfos: [String: PackageInfo],
        packageToFolder: [String: AbsolutePath],
        packageToTargetsToArtifactPaths: [String: [String: AbsolutePath]],
        packageModuleAliases: [String: [String: String]]
    ) throws -> [String: [ProjectDescription.TargetDependency]]

    /// Maps a `PackageInfo` to a `ProjectDescription.Project`.
    /// - Parameters:
    ///   - packageInfo: `PackageInfo` to be mapped
    ///   - path: Path of the package
    ///   - productTypes: Product type mapping
    ///   - baseSettings: Base settings
    ///   - targetSettings: Settings to apply to denoted targets
    ///   - projectOptions: Additional options related to the `Project`
    ///   - targetsToArtifactPaths: Mapping from a package name its targets' names to artifacts' paths
    ///   - packageModuleAliases: Package module aliases
    ///   - enabledTraits: Traits enabled for the package
    ///   - isLocal: Whether the package is the root (local) package being generated directly. Local packages keep `test` and `executable` targets and enable automatic schemes.
    /// - Returns: Mapped project
    func map(
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
    ) throws -> ProjectDescription.Project?
}
