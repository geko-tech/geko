import Collections
import Foundation

extension Array {
    mutating func alloc(_ elem: Element) -> Int {
        let id = count
        append(elem)
        return id
    }
}

struct State<P: Package, V: Version> {
    let rootPackage: P
    let rootVersion: V

    // Package -> [incompatibility id]
    var incompatibilities: OrderedDictionary<P, [Int]>

    // Set of incompatibility ids
    var contradictedIncompatibilities: Set<Int>

    var partialSolution: PartialSolution<P, V>

    // incompatibility id -> Incompatibilitiy
    var incompatibilityStore: [Incompatibility<P, V>]

    var unitPropagationBuffer: [P] = []

    // MARK: - Methods

    init(rootPackage: P, rootVersion: V) {
        var incompatibilityStore: [Incompatibility<P, V>] = []
        let notRoot = Incompatibility<P, V>.notRoot(package: rootPackage, version: rootVersion)

        let notRootId = incompatibilityStore.alloc(notRoot)

        var incompatibilities: OrderedDictionary<P, [Int]> = [:]
        incompatibilities[rootPackage] = [notRootId]

        self.rootPackage = rootPackage
        self.rootVersion = rootVersion
        self.incompatibilities = incompatibilities
        contradictedIncompatibilities = .init()
        partialSolution = .empty()
        self.incompatibilityStore = incompatibilityStore
        unitPropagationBuffer = []
    }

    /// Add an incompatibility to the state.
    mutating func addIncompatibility(incompat: Incompatibility<P, V>) {
        let id = incompatibilityStore.alloc(incompat)
        mergeIncompatibility(id: id)
    }

    /// Add an incompatibility to the state.
    mutating func addIncompatibilityFromDependencies(
        package: P,
        version: V,
        deps: DependencyConstraints<P, V>
    ) -> Range<Int> {
        // Create incompatibilities and allocate them in the store.
        let start = incompatibilityStore.count
        for dep in deps.constraints {
            let incompat = Incompatibility<P, V>.fromDependency(
                package: package,
                version: version,
                dep: dep
            )
            let _ = incompatibilityStore.alloc(incompat)
        }
        let end = incompatibilityStore.count
        let newIncompatsIdRange = Range(uncheckedBounds: (lower: start, upper: end))
        // Merge the newly created incompatibilities with the older ones.
        for id in newIncompatsIdRange {
            mergeIncompatibility(id: id)
        }

        return newIncompatsIdRange
    }

    /// Check if an incompatibility is terminal.
    func isTerminal(incompatibility: Incompatibility<P, V>) -> Bool {
        incompatibility.isTerminal(rootPackage: rootPackage, rootVersion: rootVersion)
    }

    /// Unit propagation is the core mechanism of the solving algorithm.
    /// CF <https://github.com/dart-lang/pub/blob/master/doc/solver.md#unit-propagation>
    mutating func unitPropagation(package: P) -> Result<Void, PubGrubError<P, V>> {
        unitPropagationBuffer.removeAll(keepingCapacity: true)
        unitPropagationBuffer.append(package)
        while let currentPackage = unitPropagationBuffer.popLast() {
            // Iterate over incompatibilities in reverse order
            // to evaluate first the newest incompatibilities.
            var conflictId: Int? = nil
            // We only care about incompatibilities if it contains the current package.
            incompat: for incompatId in incompatibilities[currentPackage]!.reversed() {
                if contradictedIncompatibilities.contains(incompatId) {
                    continue
                }
                let currentIncompat = incompatibilityStore[incompatId]
                switch partialSolution.relation(incompat: currentIncompat) {
                // If the partial solution satisfies the incompatibility
                // we must perform conflict resolution.
                case .satisfied:
                    conflictId = incompatId
                    break incompat
                case let .almostSatisfied(packageAlmost):
                    if !unitPropagationBuffer.contains(packageAlmost) {
                        unitPropagationBuffer.append(packageAlmost)
                    }
                    // Add (not term) to the partial solution with incompat as cause.
                    partialSolution.addDerivation(
                        package: packageAlmost,
                        cause: incompatId,
                        store: incompatibilityStore
                    )
                    // With the partial solution updated, the incompatibility is now contradicted.
                    contradictedIncompatibilities.insert(incompatId)
                case .contradicted:
                    contradictedIncompatibilities.insert(incompatId)
                default:
                    break
                }
            }

            if let incompatId = conflictId {
                let res = conflictResolution(incompatibility: incompatId)
                guard case let .success((packageAlmost, rootCause)) = res else {
                    if case let .failure(error) = res {
                        return .failure(error)
                    }
                    fatalError("This should not be possible")
                }
                unitPropagationBuffer.removeAll(keepingCapacity: true)
                unitPropagationBuffer.append(packageAlmost)
                // Add to the partial solution with incompat as cause.
                partialSolution.addDerivation(
                    package: packageAlmost,
                    cause: rootCause,
                    store: incompatibilityStore
                )
                // After conflict resolution and the partial solution update,
                // the root cause incompatibility is now contradicted.
                contradictedIncompatibilities.insert(rootCause)
            }
        }
        // If there are no more changed packages, unit propagation is done.
        return .success(())
    }

    /// Return the root cause and the backtracked model.
    /// CF <https://github.com/dart-lang/pub/blob/master/doc/solver.md#unit-propagation>
    mutating func conflictResolution(
        incompatibility: Int
    ) -> Result<(P, Int), PubGrubError<P, V>> {
        var currentIncompatId = incompatibility
        var currentIncompatChanged = false
        while true {
            if incompatibilityStore[currentIncompatId]
                .isTerminal(rootPackage: rootPackage, rootVersion: rootVersion)
            {
                return .failure(
                    PubGrubError.noSolution(
                        buildDerivationTree(incompat: currentIncompatId)
                    ))
            } else {
                let (package, satisfierSearchResult) = partialSolution.satisfierSearch(
                    incompat: incompatibilityStore[currentIncompatId],
                    store: incompatibilityStore
                )
                switch satisfierSearchResult {
                case let .differentDecisionLevels(previousSatisfierLevel):
                    backtrack(
                        incompat: currentIncompatId,
                        incompatChanged: currentIncompatChanged,
                        decisionLevel: previousSatisfierLevel
                    )
                    return .success((package, currentIncompatId))
                case let .sameDecisionLevels(satisfierCause):
                    let priorCause = Incompatibility<P, V>.priorCause(
                        incompatId: currentIncompatId,
                        satisfierCauseId: satisfierCause,
                        package: package,
                        incompatibilityStore: incompatibilityStore
                    )
                    currentIncompatId = incompatibilityStore.alloc(priorCause)
                    currentIncompatChanged = true
                }
            }
        }
    }

    /// Backtracking.
    mutating func backtrack(
        incompat: Int,
        incompatChanged: Bool,
        decisionLevel: DecisionLevel
    ) {
        partialSolution.backtrack(decisionLevel: decisionLevel, store: incompatibilityStore)
        contradictedIncompatibilities.removeAll()
        if incompatChanged {
            mergeIncompatibility(id: incompat)
        }
    }

    /// Add this incompatibility into the set of all incompatibilities.
    ///
    /// Pub collapses identical dependencies from adjacent package versions
    /// into individual incompatibilities.
    /// This substantially reduces the total number of incompatibilities
    /// and makes it much easier for Pub to reason about multiple versions of packages at once.
    ///
    /// For example, rather than representing
    /// foo 1.0.0 depends on bar ^1.0.0 and
    /// foo 1.1.0 depends on bar ^1.0.0
    /// as two separate incompatibilities,
    /// they are collapsed together into the single incompatibility {foo ^1.0.0, not bar ^1.0.0}
    /// (provided that no other version of foo exists between 1.0.0 and 2.0.0).
    /// We could collapse them into { foo (1.0.0 ∪ 1.1.0), not bar ^1.0.0 }
    /// without having to check the existence of other versions though.
    ///
    /// Here we do the simple stupid thing of just growing the Vec.
    /// It may not be trivial since those incompatibilities
    /// may already have derived others.
    mutating func mergeIncompatibility(id: Int) {
        for (pkg, _) in incompatibilityStore[id].packageTerms {
            incompatibilities[pkg, default: []].append(id)
        }
    }

    func buildDerivationTree(incompat: Int) -> DerivationTree<P, V> {
        let sharedIds = findSharedIds(incompat: incompat)
        return Incompatibility<P, V>.buildDerivationTree(
            selfId: incompat,
            sharedIds: sharedIds,
            store: incompatibilityStore
        )
    }

    func findSharedIds(incompat: Int) -> Set<Int> {
        var allIds: Set<Int> = .init()
        var sharedIds: Set<Int> = .init()
        var stack = [incompat]
        while let i = stack.popLast() {
            if case let .some((id1, id2)) = incompatibilityStore[i].causes() {
                if allIds.contains(i) {
                    sharedIds.insert(i)
                } else {
                    allIds.insert(i)
                    stack.append(id1)
                    stack.append(id2)
                }
            }
        }
        return sharedIds
    }
}
