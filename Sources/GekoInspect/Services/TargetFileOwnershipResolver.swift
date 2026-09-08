import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

public struct FileTargetOwnership: Equatable {
    
    public let file: AbsolutePath
    public let targets: [GraphTarget]

    public init(file: AbsolutePath, targets: [GraphTarget]) {
        self.file = file
        self.targets = targets
    }
}

public protocol TargetFileOwnershipResolving {
    func resolve(_ files: [AbsolutePath], graph: Graph) throws -> [FileTargetOwnership]
}

public final class TargetFileOwnershipResolver {

    public init() {}

    public func resolve(_ files: [AbsolutePath], graph: Graph) throws -> [FileTargetOwnership] {
        return []
    }
}
