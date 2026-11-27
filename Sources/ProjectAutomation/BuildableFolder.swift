import Foundation

/// The structure defining the buildable folder
public struct BuildableFolder: Codable, Equatable {
    /// Path to directory
    public let path: String
    
    /// List of excluded subdirectories
    public var exceptions: [String]

    public init(
        path: String,
        exceptions: [String]
    ) {
        self.path = path
        self.exceptions = exceptions
    }
}
