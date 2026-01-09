import Collections
import Foundation

public struct OfflineDependencyProvider<P: Package, V: Version>: PubGrubDependencyProvider {
    public var dependencies: [P: OrderedDictionary<V, DependencyConstraints<P, V>>] = [:]

    public init() {}

    /// Registers the dependencies of a package and version pair.
    /// Dependencies must be added with a single call to
    /// [add_dependencies](OfflineDependencyProvider::add_dependencies).
    /// All subsequent calls to
    /// [add_dependencies](OfflineDependencyProvider::add_dependencies) for a given
    /// package version pair will replace the dependencies by the new ones.
    ///
    /// The API does not allow to add dependencies one at a time to uphold an assumption that
    /// [OfflineDependencyProvider.get_dependencies(p, v)](OfflineDependencyProvider::get_dependencies)
    /// provides all dependencies of a given package (p) and version (v) pair.
    public mutating func add(
        _ package: P,
        _ version: V,
        _ dependencies: OrderedDictionary<P, VersionSet<V>>
    ) {
        let v = version
        self.dependencies[package, default: [:]][v] = .init(constraints: dependencies)
    }

    /// Lists packages that have been saved.
    public func packages() -> [P] {
        Array(dependencies.keys)
    }

    /// Lists versions of saved packages in sorted order.
    /// Returns [None] if no information is available regarding that package.
    public func versions(package: P) -> [V]? {
        dependencies[package].map { Array($0.keys) }
    }

    /// Lists dependencies of a given package and version.
    /// Returns [None] if no information is available regarding that package and version pair.
    public func dependencies(package: P, version: V) -> DependencyConstraints<P, V>? {
        dependencies[package]?[version]
    }

    public func choosePackageVersion(
        potentialPackages: [(P, VersionSet<V>)]
    ) async throws -> (P, V?) {
        try await choosePackageWithFewestVersions(
            listAvailableVersions: { p -> [V] in
                let constrs = dependencies[p]?.keys ?? []
                return Array(constrs)
            },
            potentialPackages: potentialPackages
        )
    }

    public func getDependencies(
        package: P,
        version: V
    ) async throws -> Dependencies<P, V> {
        if let deps = dependencies(package: package, version: version) {
            return .known(deps)
        }
        return .unknown
    }
}
