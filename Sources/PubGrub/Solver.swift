import Collections
import Foundation

public class PubGrubSolver<DP: PubGrubDependencyProvider> {
    private let dependencyProvider: DP

    public typealias P = DP.Pkg
    public typealias V = DP.Ver

    public init(dependencyProvider: DP) {
        self.dependencyProvider = dependencyProvider
    }

    public func resolve(
        package: P,
        version: V
    ) async throws -> [P: V] {
        var state: State<P, V> = .init(rootPackage: package, rootVersion: version)
        var addedDependencies: [P: OrderedSet<V>] = [:]
        var next = package
        loop: while true {
            try dependencyProvider.shouldCancel()

            if case let .failure(error) = state.unitPropagation(package: next) {
                throw error
            }

            let potentialPackages = state.partialSolution.potentialPackages()
            if potentialPackages == nil {
                guard let solution = state.partialSolution.extractSolution() else {
                    throw PubGrubError<P, V>
                        .failure("How did we end up with no package to choose but no solution?")
                }
                return solution
            }
            let decision = try await dependencyProvider.choosePackageVersion(potentialPackages: potentialPackages!)
            next = decision.0

            guard let termIntersection = state.partialSolution.termIntersectionForPackage(next) else {
                throw PubGrubError<P, V>.failure("a package was chosen but we dont have a term")
            }
            guard let v = decision.1 else {
                let inc = Incompatibility<P, V>.noVersions(package: next, term: termIntersection)
                state.addIncompatibility(incompat: inc)
                continue
            }
            if !termIntersection.contains(version: v) {
                throw PubGrubError<P, V>.errorChoosingPackageVersion(
                    "choosePackageVersion picked an incompatible version"
                )
            }

            if addedDependencies[next, default: .init()].append(v).inserted {
                let p = next
                let dependencies: DependencyConstraints<P, V>
                switch try await dependencyProvider.getDependencies(package: p, version: v) {
                case .unknown:
                    state.addIncompatibility(incompat: .unavailableDependencies(package: p, version: v))
                    continue loop
                case let .known(x):
                    if x.constraints[p] != nil {
                        throw PubGrubError.selfDependency(package: p, version: v)
                    }
                    if let (dependent, _) = x.constraints
                        .first(where: { $0.value == VersionSet<V>.none() })
                    {
                        throw PubGrubError.dependencyOnTheEmptySet(
                            package: p,
                            version: v,
                            dependent: dependent
                        )
                    }
                    dependencies = x
                }

                // Add that package and version if the dependencies are not problematic.
                let depIncompats = state.addIncompatibilityFromDependencies(
                    package: p, version: v, deps: dependencies
                )

                // TODO: I don't think this check can actually happen.
                // We might want to put it under #[cfg(debug_assertions)].
                if state.incompatibilityStore[depIncompats]
                    .contains(where: { state.isTerminal(incompatibility: $0) })
                {
                    throw PubGrubError<P, V>
                        .failure("Root package depends on itself at a different version?")
                }
                state.partialSolution.addVersion(
                    package: p,
                    version: v,
                    newIncompatibilities: depIncompats,
                    store: state.incompatibilityStore
                )
            } else {
                state.partialSolution.addDecision(package: next, version: v)
            }
        }
    }
}

/// This is a helper function to make it easy to implement
/// `DependencyProvider.choosePackageVersion`.
///
/// It takes a function `listAvailableVersions` that takes a package and returns an iterator
/// of the available versions in preference order.
/// The helper finds the package from the `packages` argument with the fewest versions from
/// `listAvailableVersions` contained in the constraints. Then takes that package and finds the
/// first version contained in the constraints.
public func choosePackageWithFewestVersions<P: Package, V: Version>(
    listAvailableVersions: (P) async throws -> [V],
    potentialPackages: [(P, VersionSet<V>)]
) async throws -> (P, V?) {
    var filteredPackageVersions: [P: Int] = [:]
    for (pkg, range) in potentialPackages {
        filteredPackageVersions[pkg] = try await listAvailableVersions(pkg)
            .filter { v in range.contains(v) }
            .count
    }
    let (pkg, range) = potentialPackages.min(
        by: { filteredPackageVersions[$0.0]! < filteredPackageVersions[$1.0]! }
    )!
    let version = try await listAvailableVersions(pkg).last(where: { v in range.contains(v) })
    return (pkg, version)
}
