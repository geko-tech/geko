import Foundation

public protocol Version: Equatable, Hashable, Comparable, CustomStringConvertible {
    var isPreRelease: Bool { get }

    func asReleaseVersion() -> Self
}
