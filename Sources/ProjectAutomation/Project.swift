import Foundation

/// The structure defining the output schema of a Xcode project.
public struct Project: Codable, Equatable {
    /// The name of the project.
    public let name: String

    /// The absolute path of the project.
    public let path: String

    /// Indicates whether the project is imported through `Dependencies.swift`.
    public let isExternal: Bool

    /// The targets this project produces.
    public let targets: [Target]

    /// The schemes available to this project.
    public let schemes: [Scheme]

    public init(
        name: String,
        path: String,
        isExternal: Bool,
        targets: [Target] = [Target](),
        schemes: [Scheme] = [Scheme]()
    ) {
        self.name = name
        self.path = path
        self.isExternal = isExternal
        self.targets = targets
        self.schemes = schemes
    }
}
