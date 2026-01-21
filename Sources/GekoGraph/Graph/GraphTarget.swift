import Foundation
import ProjectDescription

public struct GraphTarget: Equatable, Hashable, Comparable, CustomDebugStringConvertible, CustomStringConvertible, Codable {
    /// Path to the directory that contains the project where the target is defined.
    public let path: AbsolutePath

    /// Target representation.
    public let target: Target

    /// Project that contains the target.
    public let project: Project

    public init(
        path: AbsolutePath,
        target: consuming Target,
        project: consuming Project
    ) {
        self.path = consume path
        self.target = consume target
        self.project = consume project
    }

    public static func < (lhs: GraphTarget, rhs: GraphTarget) -> Bool {
        (lhs.path, lhs.target) < (rhs.path, rhs.target)
    }

    // MARK: - CustomDebugStringConvertible/CustomStringConvertible

    public var debugDescription: String {
        description
    }

    public var description: String {
        "Target '\(target.name)' at path '\(project.path)'"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
        hasher.combine(target.name)
    }
}
