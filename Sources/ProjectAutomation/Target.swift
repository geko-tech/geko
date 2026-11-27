import Foundation

/// The structure defining the output schema of a target.
public struct Target: Codable, Equatable {
    /// The name of the target.
    public let name: String

    /// The product type the target produces.
    public let product: String

    /// List of file paths that are the target's sources.
    public let sources: [String]
    
    /// List of directories that are the target's buiildable folders
    public var buildableFolders: [BuildableFolder]

    /// List of file paths that are the target's resources.
    public let resources: [String]

    /// The target’s dependencies.
    public let dependencies: [TargetDependency]

    public init(
        name: String,
        product: String,
        sources: [String],
        buildableFolders: [BuildableFolder],
        resources: [String],
        dependencies: [TargetDependency]
    ) {
        self.name = name
        self.product = product
        self.sources = sources
        self.buildableFolders = buildableFolders
        self.resources = resources
        self.dependencies = dependencies
    }
}
