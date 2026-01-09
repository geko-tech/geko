import Collections
import Foundation

struct Incompatibility<P: Package, V: Version>: CustomStringConvertible {
    let packageTerms: OrderedDictionary<P, Term<V>>
    let kind: IncompatibilityKind<P, V>

    var description: String {
        DefaultStringReporter().stringTerms(packageTerms)
    }

    // Creates initial not root incompatibility
    static func notRoot(package: P, version: V) -> Incompatibility<P, V> {
        .init(
            packageTerms: [package: .negative(VersionSet<V>.exact(version: version))],
            kind: .notRoot(package, version)
        )
    }

    static func noVersions(package: P, term: Term<V>) -> Incompatibility<P, V> {
        let range =
            switch term {
            case let .positive(r):
                r
            case .negative:
                fatalError("No version should have a positive term")
            }

        return .init(
            packageTerms: [package: term],
            kind: .noVersions(package, range)
        )
    }

    static func unavailableDependencies(package: P, version: V) -> Incompatibility<P, V> {
        let range = VersionSet<V>.exact(version: version)
        return .init(
            packageTerms: [package: .positive(range)],
            kind: .unavailableDependencies(package, range)
        )
    }

    static func fromDependency(package: P, version: V, dep: (P, VersionSet<V>)) -> Incompatibility<P, V> {
        let range1 = VersionSet<V>.exact(version: version)
        let (p2, range2) = dep

        return .init(
            packageTerms: [
                package: Term<V>.positive(range1),
                p2: Term<V>.negative(range2),
            ],
            kind: .fromDependencyOf(package, range1, p2, range2)
        )
    }

    static func priorCause(
        incompatId: Int,
        satisfierCauseId: Int,
        package: P,
        incompatibilityStore: [Incompatibility<P, V>]
    ) -> Incompatibility<P, V> {
        let kind = IncompatibilityKind<P, V>.derivedFrom(incompatId, satisfierCauseId)
        var packageTerms = incompatibilityStore[incompatId].packageTerms
        let t1 = packageTerms.removeValue(forKey: package)!
        let satisfierCauseTerms = incompatibilityStore[satisfierCauseId].packageTerms

        var filteredSatisfierCauseTerms = satisfierCauseTerms
        filteredSatisfierCauseTerms.removeValue(forKey: package)
        packageTerms.merge(filteredSatisfierCauseTerms) { t1, t2 in t1.intersection(t2) }

        let term = t1.union(satisfierCauseTerms[package]!)
        if term != Term<V>.any() {
            packageTerms[package] = term
        }

        return .init(packageTerms: packageTerms, kind: kind)
    }

    func isTerminal(rootPackage: P, rootVersion: V) -> Bool {
        if packageTerms.count == 0 {
            return true
        } else if packageTerms.count > 1 {
            return false
        } else {
            let package = packageTerms.keys.first!
            let term = packageTerms[package]!
            return package == rootPackage && term.contains(version: rootVersion)
        }
    }

    func get(package: P) -> Term<V>? {
        packageTerms[package]
    }

    func causes() -> (Int, Int)? {
        guard case let .derivedFrom(id1, id2) = kind else {
            return nil
        }

        return (id1, id2)
    }

    static func buildDerivationTree(
        selfId: Int,
        sharedIds: Set<Int>,
        store: [Incompatibility<P, V>]
    ) -> DerivationTree<P, V> {
        switch store[selfId].kind {
        case let .derivedFrom(id1, id2):
            let cause1 = buildDerivationTree(selfId: id1, sharedIds: sharedIds, store: store)
            let cause2 = buildDerivationTree(selfId: id2, sharedIds: sharedIds, store: store)
            let derived = Derived(
                terms: store[selfId].packageTerms,
                sharedId: selfId,
                cause1: Box(cause1),
                cause2: Box(cause2)
            )
            return DerivationTree<P, V>.derived(derived)
        case let .notRoot(package, version):
            return DerivationTree<P, V>.external(External<P, V>.notRoot(package, version))
        case let .noVersions(package, range):
            return DerivationTree<P, V>.external(External<P, V>.noVersions(package, range))
        case let .unavailableDependencies(package, range):
            return DerivationTree<P, V>.external(External<P, V>.unavailableDependencies(package, range))
        case let .fromDependencyOf(package, range, depPackage, depRange):
            return DerivationTree<P, V>.external(
                External<P, V>.fromDependencyOf(package, range, depPackage, depRange)
            )
        }
    }

    func relation(terms: (P) -> Term<V>?) -> IncompatibilityRelation<P> {
        var relation = IncompatibilityRelation<P>.satisfied
        for (package, incompatTerm) in packageTerms {
            switch terms(package).map({ t in incompatTerm.relationWith(t) }) {
            case .some(.satisfied):
                break
            case .some(.contradicted):
                return IncompatibilityRelation<P>.contradicted(package)
            case .none, .some(.inconclusive):
                if case .satisfied = relation {
                    relation = .almostSatisfied(package)
                } else {
                    relation = .inconclusive
                }
            }
        }
        return relation
    }
}

enum IncompatibilityKind<P: Package, V: Version> {
    /// Initial incompatibility aiming at picking the root package for the first decision.
    case notRoot(P, V)
    /// There are no versions in the given range for this package.
    case noVersions(P, VersionSet<V>)
    /// Dependencies of the package are unavailable for versions in that range.
    case unavailableDependencies(P, VersionSet<V>)
    /// Incompatibility coming from the dependencies of a given package.
    case fromDependencyOf(P, VersionSet<V>, P, VersionSet<V>)
    /// Derived from two causes. Stores cause ids.
    case derivedFrom(Int, Int)
}

enum IncompatibilityRelation<P: Package> {
    /// We say that a set of terms S satisfies an incompatibility I
    /// if S satisfies every term in I.
    case satisfied
    /// We say that S contradicts I
    /// if S contradicts at least one term in I.
    case contradicted(P)
    /// If S satisfies all but one of I's terms and is inconclusive for the remaining term,
    /// we say S "almost satisfies" I and we call the remaining term the "unsatisfied term".
    case almostSatisfied(P)
    /// Otherwise, we say that their relation is inconclusive.
    case inconclusive
}
