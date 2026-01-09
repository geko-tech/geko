import Collections
import Foundation

struct DecisionLevel: Equatable, Comparable {
    var level: UInt

    func increment() -> DecisionLevel {
        .init(level: level + 1)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.level < rhs.level
    }
}

struct PackageAssignments<P: Package, V: Version> {
    var smallestDecisionLevel: DecisionLevel
    var highestDecisionLevel: DecisionLevel
    var datedDerivations: [DatedDerivation<P, V>]
    var assignmentsIntersection: AssignmentsIntersection<V>

    func satisfier(
        _ package: P,
        _ incompatTerm: Term<V>,
        _ startTerm: Term<V>,
        _ store: [Incompatibility<P, V>]
    ) -> (Int, Int, DecisionLevel) {
        // Term where we accumulate intersections until incompat_term is satisfied.
        var accumTerm = startTerm
        // Indicate if we found a satisfier in the list of derivations, otherwise it will be the decision.
        for (idx, datedDerivation) in datedDerivations.enumerated() {
            let thisTerm = store[datedDerivation.cause].get(package: package)!.negate()
            accumTerm = accumTerm.intersection(thisTerm)
            if accumTerm.subsetOf(incompatTerm) {
                // We found the derivation causing satisfaction.
                return (
                    idx,
                    datedDerivation.globalIndex,
                    datedDerivation.decisionLevel
                )
            }
        }
        // If it wasn't found in the derivations,
        // it must be the decision which is last (if called in the right context).
        switch assignmentsIntersection {
        case let .decision((globalIndex, _, _)):
            return (datedDerivations.count, globalIndex, highestDecisionLevel)
        case .derivations:
            fatalError(
                """
                while processing package \(package),
                accumTerm = \(accumTerm) has overlap with incompatTerm = \(startTerm),
                which means the last assignment should have been a decision,
                but insteat it was a derivation. This shouldn't be possible!
                "(Maybe you Version ordering is broken?"
                """)
        }
    }
}

struct DatedDerivation<P: Package, V: Version> {
    var globalIndex: Int
    var decisionLevel: DecisionLevel
    /// incompatibility id
    var cause: Int
}

enum AssignmentsIntersection<V: Version> {
    case decision((Int, V, Term<V>))
    case derivations(Term<V>)

    /// Returns the term intersection of all assignments (decision included).
    func term() -> Term<V> {
        switch self {
        case let .decision((_, _, term)):
            return term
        case let .derivations(term):
            return term
        }
    }

    /// A package is a potential pick if there isn't an already
    /// selected version (no "decision")
    /// and if it contains at least one positive derivation term
    /// in the partial solution.
    func potentialPackageFilter<P: Package>(package: P) -> (P, VersionSet<V>)? {
        switch self {
        case .decision:
            return nil
        case let .derivations(termIntersection):
            if termIntersection.isPositive {
                return (package, termIntersection.unwrapPositive())
            } else {
                return nil
            }
        }
    }
}

enum SatisfierSearch<P: Package, V: Version> {
    case differentDecisionLevels(previousSatisfierLevel: DecisionLevel)
    /// satisfierCause - incompatibility id
    case sameDecisionLevels(satisfierCause: Int)
}

struct PartialSolution<P: Package, V: Version> {
    var nextGlobalIndex: Int
    var currentDecisionLevel: DecisionLevel
    var packageAssignments: OrderedDictionary<P, PackageAssignments<P, V>>

    static func empty() -> PartialSolution<P, V> {
        .init(
            nextGlobalIndex: 0,
            currentDecisionLevel: DecisionLevel(level: 0),
            packageAssignments: [:]
        )
    }

    mutating func addDecision(package: P, version: V) {
        // Check that add_decision is never used in the wrong context.
        // if cfg!(debug_assertions) {
        guard var pa = packageAssignments[package] else {
            fatalError("Derivations must already exist")
        }
        switch pa.assignmentsIntersection {
        case .decision:
            fatalError("Already existing decision")
        case let .derivations(term):
            precondition(term.contains(version: version))
        }
        // }
        currentDecisionLevel = currentDecisionLevel.increment()

        pa.highestDecisionLevel = currentDecisionLevel
        pa.assignmentsIntersection = AssignmentsIntersection<V>.decision(
            (
                nextGlobalIndex,
                version,
                Term<V>.exact(version: version)
            ))
        packageAssignments[package] = pa

        nextGlobalIndex += 1
    }

    mutating func addDerivation(
        package: P,
        cause: Int,
        store: [Incompatibility<P, V>]
    ) {
        // use std::collections::hash_map::Entry;
        let term = store[cause].get(package: package)!.negate()
        let datedDerivation = DatedDerivation<P, V>(
            globalIndex: nextGlobalIndex,
            decisionLevel: currentDecisionLevel,
            cause: cause
        )
        nextGlobalIndex += 1

        if var pa = packageAssignments[package] {
            pa.highestDecisionLevel = currentDecisionLevel
            switch pa.assignmentsIntersection {
            case .decision:
                fatalError("addDerivation should not be called after a decision")
            case let .derivations(t):
                let newT = t.intersection(term)
                pa.assignmentsIntersection = .derivations(newT)
            }
            pa.datedDerivations.append(datedDerivation)
            packageAssignments[package] = pa
        } else {
            packageAssignments[package] = PackageAssignments(
                smallestDecisionLevel: currentDecisionLevel,
                highestDecisionLevel: currentDecisionLevel,
                datedDerivations: [datedDerivation],
                assignmentsIntersection: AssignmentsIntersection<V>.derivations(term)
            )
        }
    }

    func potentialPackages() -> [(P, VersionSet<V>)]? {
        let result = packageAssignments.compactMap { p, pa in
            pa.assignmentsIntersection.potentialPackageFilter(package: p)
        }

        if result.isEmpty {
            return nil
        } else {
            return result
        }
    }

    /// If a partial solution has, for every positive derivation,
    /// a corresponding decision that satisfies that assignment,
    /// it's a total solution and version solving has succeeded.
    func extractSolution() -> [P: V]? {
        var solution: [P: V] = [:]
        for (p, pa) in packageAssignments {
            switch pa.assignmentsIntersection {
            case let .decision((_, v, _)):
                solution[p] = v
            case let .derivations(term):
                if term.isPositive {
                    return nil
                }
            }
        }
        return solution
    }

    /// Backtrack the partial solution to a given decision level.
    mutating func backtrack(
        decisionLevel: DecisionLevel,
        store: [Incompatibility<P, V>]
    ) {
        currentDecisionLevel = decisionLevel
        packageAssignments = packageAssignments.filter { p in
            // Remove all entries that have a smallest decision level higher than the backtrack target.
            p.value.smallestDecisionLevel <= decisionLevel
        }
        .map { kv in
            let p = kv.key
            var pa = kv.value
            // Do not change entries older than the backtrack decision level target.
            if pa.highestDecisionLevel <= decisionLevel {
                return (p, pa)
            }

            // smallest_decision_level <= decision_level < highest_decision_level
            //
            // Since decision_level < highest_decision_level,
            // We can be certain that there will be no decision in this package assignments
            // after backtracking, because such decision would have been the last
            // assignment and it would have the "highest_decision_level".

            // Truncate the history.
            while let lastDecisionLevel = pa.datedDerivations.last?.decisionLevel,
                lastDecisionLevel > decisionLevel
            {
                pa.datedDerivations.removeLast()
            }
            precondition(!pa.datedDerivations.isEmpty)

            // Update highest_decision_level.
            pa.highestDecisionLevel = pa.datedDerivations.last!.decisionLevel

            // Recompute the assignments intersection.
            pa.assignmentsIntersection = AssignmentsIntersection.derivations(
                pa.datedDerivations.reduce(into: Term<V>.any()) { acc, datedDerivation in
                    let term = store[datedDerivation.cause].get(package: p)!.negate()
                    acc = acc.intersection(term)
                }
            )

            return (p, pa)
        }
        .reduce(into: OrderedDictionary<P, PackageAssignments<P, V>>()) { acc, p in acc[p.0] = p.1 }
    }

    /// We can add the version to the partial solution as a decision
    /// if it doesn't produce any conflict with the new incompatibilities.
    /// In practice I think it can only produce a conflict if one of the dependencies
    /// (which are used to make the new incompatibilities)
    /// is already in the partial solution with an incompatible version.
    mutating func addVersion(
        package: P,
        version: V,
        newIncompatibilities: Range<Int>,
        store: [Incompatibility<P, V>]
    ) {
        let exact = Term<V>.exact(version: version)
        let notSatisfied: (Int) -> Bool = { incompatId in
            let incompat = store[incompatId]
            let relation = incompat.relation { p in
                if p == package {
                    return exact
                } else {
                    return termIntersectionForPackage(p)
                }
            }
            if case .satisfied = relation {
                return false
            }
            return true
        }

        // Check none of the dependencies (new_incompatibilities)
        // would create a conflict (be satisfied).
        if newIncompatibilities.allSatisfy(notSatisfied) {
            addDecision(package: package, version: version)
        }
    }

    /// Check if the terms in the partial solution satisfy the incompatibility.
    func relation(incompat: Incompatibility<P, V>) -> IncompatibilityRelation<P> {
        incompat.relation { package in termIntersectionForPackage(package) }
    }

    /// Retrieve intersection of terms related to package.
    func termIntersectionForPackage(_ package: P) -> Term<V>? {
        packageAssignments[package].map { pa in pa.assignmentsIntersection.term() }
    }

    /// Figure out if the satisfier and previous satisfier are of different decision levels.
    func satisfierSearch(
        incompat: Incompatibility<P, V>,
        store: [Incompatibility<P, V>]
    ) -> (P, SatisfierSearch<P, V>) {
        let satisfiedMap = PartialSolution<P, V>.findSatisfier(
            incompat: incompat,
            packageAssignments: packageAssignments,
            store: store
        )
        let max = satisfiedMap.max { p1, p2 in
            p1.value.1 <= p2.value.1
        }!
        let satisfierPackage = max.key
        let (satisfierIndex, _, satisfierDecisionLevel) = max.value

        let previousSatisfierLevel = PartialSolution<P, V>.findPreviousSatisfier(
            incompat,
            satisfierPackage,
            satisfiedMap,
            packageAssignments,
            store
        )

        if previousSatisfierLevel < satisfierDecisionLevel {
            let searchResult = SatisfierSearch<P, V>
                .differentDecisionLevels(previousSatisfierLevel: previousSatisfierLevel)
            return (satisfierPackage, searchResult)
        } else {
            let satisfierPa = packageAssignments[satisfierPackage]!
            let dd = satisfierPa.datedDerivations[satisfierIndex]
            let searchResult = SatisfierSearch<P, V>
                .sameDecisionLevels(satisfierCause: dd.cause)
            return (satisfierPackage, searchResult)
        }
    }

    /// A satisfier is the earliest assignment in partial solution such that the incompatibility
    /// is satisfied by the partial solution up to and including that assignment.
    ///
    /// Returns a map indicating for each package term, when that was first satisfied in history.
    /// If we effectively found a satisfier, the returned map must be the same size that incompat.
    ///
    /// Question: This is possible since we added a "global_index" to every dated_derivation.
    /// It would be nice if we could get rid of it, but I don't know if then it will be possible
    /// to return a coherent previous_satisfier_level.
    static func findSatisfier(
        incompat: Incompatibility<P, V>,
        packageAssignments: OrderedDictionary<P, PackageAssignments<P, V>>,
        store: [Incompatibility<P, V>]
    ) -> [P: (Int, Int, DecisionLevel)] {
        var satisfied: [P: (Int, Int, DecisionLevel)] = [:]
        for (package, incompatTerm) in incompat.packageTerms {
            let pa = packageAssignments[package]!
            let anyTerm: Term<V> = .any()
            satisfied[package] = pa.satisfier(package, incompatTerm, anyTerm, store)
        }
        return satisfied
    }

    /// Earliest assignment in the partial solution before satisfier
    /// such that incompatibility is satisfied by the partial solution up to
    /// and including that assignment plus satisfier.
    static func findPreviousSatisfier(
        _ incompat: Incompatibility<P, V>,
        _ satisfierPackage: P,
        _ satisfiedMap: [P: (Int, Int, DecisionLevel)],
        _ packageAssignments: OrderedDictionary<P, PackageAssignments<P, V>>,
        _ store: [Incompatibility<P, V>]
    ) -> DecisionLevel {
        var satisfiedMap = satisfiedMap
        // First, let's retrieve the previous derivations and the initial accumTerm.
        let satisfierPa = packageAssignments[satisfierPackage]!
        let (satisfierIndex, _, _) = satisfiedMap[satisfierPackage]!

        let accumTerm: Term<V>
        if satisfierIndex == satisfierPa.datedDerivations.count {
            switch satisfierPa.assignmentsIntersection {
            case .derivations:
                fatalError("must be a decision")
            case let .decision((_, _, term)):
                accumTerm = term
            }
        } else {
            let dd = satisfierPa.datedDerivations[satisfierIndex]
            accumTerm = store[dd.cause].get(package: satisfierPackage)!.negate()
        }

        let incompatTerm = incompat.get(package: satisfierPackage)!

        satisfiedMap[satisfierPackage] = satisfierPa.satisfier(
            satisfierPackage, incompatTerm, accumTerm, store
        )

        // Finally, let's identify the decision level of that previous satisfier.
        let (_, (_, _, decisionLevel)) =
            satisfiedMap
            .max { p1, p2 in p1.value.1 <= p2.value.1 }!
        return max(decisionLevel, DecisionLevel(level: 1))
    }
}
