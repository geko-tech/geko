import Collections
import Foundation

public enum Dependencies<P: Package, V: Version> {
    case unknown
    case known(DependencyConstraints<P, V>)
}

public struct DependencyConstraints<P: Package, V: Version> {
    public let constraints: OrderedDictionary<P, VersionRange<V>>

    public init(constraints: OrderedDictionary<P, VersionRange<V>>) {
        self.constraints = constraints
    }
}
