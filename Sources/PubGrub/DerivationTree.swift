import Collections
import Foundation

public class Box<T> {
    public var value: T

    public init(_ value: T) {
        self.value = value
    }
}

public enum External<P: Package, V: Version> {
    case notRoot(P, V)
    case noVersions(P, VersionSet<V>)
    case unavailableDependencies(P, VersionSet<V>)
    case fromDependencyOf(P, VersionSet<V>, P, VersionSet<V>)
}

public struct Derived<P: Package, V: Version> {
    public let terms: OrderedDictionary<P, Term<V>>

    public let sharedId: Int?
    public let cause1: Box<DerivationTree<P, V>>
    public let cause2: Box<DerivationTree<P, V>>
}

public enum DerivationTree<P: Package, V: Version> {
    case external(External<P, V>)
    case derived(Derived<P, V>)

    mutating func collapseNoVersions() {
        guard case let .derived(derived) = self else {
            return
        }

        switch (derived.cause1.value, derived.cause2.value) {
        case (let .external(External.noVersions(p, r)), var cause2):
            cause2.collapseNoVersions()
            self = cause2.mergeNoVersions(package: p, range: r)
        case (var cause1, let .external(External.noVersions(p, r))):
            cause1.collapseNoVersions()
            self = cause1.mergeNoVersions(package: p, range: r)
        default:
            derived.cause1.value.collapseNoVersions()
            derived.cause2.value.collapseNoVersions()
        }
    }

    func mergeNoVersions(package: P, range: VersionSet<V>) -> DerivationTree<P, V> {
        switch self {
        case .derived:
            return self
        case .external(External.notRoot):
            fatalError("How did we end up with a NoVersions merged with a NotRoot?")
        case let .external(External.noVersions(_, r)):
            return DerivationTree<P, V>.external(
                External<P, V>.noVersions(package, range.union(r))
            )
        case let .external(External.unavailableDependencies(_, r)):
            return DerivationTree<P, V>.external(
                External<P, V>
                    .unavailableDependencies(package, range.union(r))
            )
        case let .external(External.fromDependencyOf(p1, r1, p2, r2)):
            if p1 == package {
                return DerivationTree<P, V>.external(
                    External<P, V>.fromDependencyOf(p1, r1.union(range), p2, r2)
                )
            } else {
                return DerivationTree<P, V>.external(
                    External<P, V>.fromDependencyOf(p1, r1, p2, r2.union(range))
                )
            }
        }
    }
}
