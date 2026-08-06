import Collections
import Foundation
import GekoCocoapods
import GekoGraph
import GekoRegistry
import GekoSupport
import ProjectDescription
import PubGrub

private let rootName = "root"

struct RegistryDependencyGraph {
    var specs: [RegistryPackage]
}

struct DependencyGraph {
    var cocoapodsGraph: CocoapodsDependencyGraph
    var registryGraph: RegistryDependencyGraph

    static let empty: DependencyGraph = .init(
        cocoapodsGraph: .init(specs: []),
        registryGraph: .init(specs: [])
    )
}

fileprivate struct PackageTypeKey: Hashable {
    let package: String
    let version: ProjectDescription.PackageVersion
}

fileprivate enum PackageType {
    case cocoapods
    case registry
}

final class DependenciesResolver {
    private let cocoapodsResolver: CocoapodsDependenciesResolver
    private let registryResolver: RegistryResolver

    private var packageTypes: [PackageTypeKey: PackageType] = [:]

    init(
        cocoapodsResolver: CocoapodsDependenciesResolver,
        registryResolver: RegistryResolver
    ) {
        self.cocoapodsResolver = cocoapodsResolver
        self.registryResolver = registryResolver
    }
}

extension DependenciesResolver {
    func resolve() async throws -> DependencyGraph {
        try await cocoapodsResolver.prepare()

        let resolver = PubGrubSolver(dependencyProvider: self)

        let clock = SuspendingClock()
        let startTime = clock.now

        let resolvedPackages: [Package: Version]
        do {
            resolvedPackages = try await resolver.resolve(package: rootName, version: .init(1, 0, 0))
        } catch let PubGrubError<Package, Version>.noSolution(derivationTree) {
            throw CocoapodsDependenciesResolverError.noSolution(
                DefaultStringReporter.report(derivationTree: derivationTree, colored: Environment.shared.shouldOutputBeColoured)
            )
        }

        if logger.logLevel == .debug {
            let timeElapsed = clock.now - startTime
            logger.debug("------------------------------------------")
            logger.debug("Resolution ended. Took \(timeElapsed)")
            logger.debug("Resolved packages:")
            for p in resolvedPackages.keys.sorted() {
                let v = resolvedPackages[p]!
                logger.debug("\(p): \(v)")
            }
            logger.debug("------------------------------------------")
        }

        var cocoapodsPackageGraph: [String: CocoapodsVersion] = [:]
        var registryPackageGraph: [String: PackageVersion] = [:]

        for kv in resolvedPackages {
            let (package, version) = kv

            switch packageTypes[.init(package: package, version: version)] {
            case .cocoapods:
                cocoapodsPackageGraph[package] = version
            case .registry:
                registryPackageGraph[package] = version
            case nil:
                fatalError("фатал ерруре")
            }
        }

//        dump(packageTypes)
//        exit(0)

        var resultGraph: DependencyGraph = .empty
        resultGraph.cocoapodsGraph = try await cocoapodsResolver.resolve(packages: cocoapodsPackageGraph)
        resultGraph.registryGraph = try await registryResolver.resolve(packages: registryPackageGraph)

        return resultGraph
    }
}

extension DependenciesResolver: PubGrubDependencyProvider {
    typealias Package = String
    typealias Version = ProjectDescription.PackageVersion

    func choosePackageVersion(
        potentialPackages: [(Package, VersionSet<Version>)]
    ) async throws -> (Package, Version?) {
        let (registryPackage, registryVersion) = try await registryResolver.choosePackageVersion(potentialPackages: potentialPackages)

        if let registryVersion {
            self.packageTypes[.init(package: registryPackage, version: registryVersion)] = .registry
            return (registryPackage, registryVersion)
        }

        let (cocoapodsPackage, cocoapodsVersion) = try await cocoapodsResolver.choosePackageVersion(potentialPackages: potentialPackages)

        if let cocoapodsVersion {
            self.packageTypes[.init(package: cocoapodsPackage, version: cocoapodsVersion)] = .cocoapods
            return (cocoapodsPackage, cocoapodsVersion)
        }

        return (cocoapodsPackage, cocoapodsVersion)
    }

    func getDependencies(
        package: String,
        version: Version
    ) async throws -> PubGrub.Dependencies<Package, Version> {
        if package == rootName {
            let cocoapodsRootDependencies = try await cocoapodsResolver.getDependencies(package: package, version: version)
            let registryRootDependencies = try await registryResolver.getDependencies(package: package, version: version)

            guard
                case let .known(cps) = cocoapodsRootDependencies,
                case let .known(rs) = registryRootDependencies
            else {
                dump(cocoapodsRootDependencies)
                dump(registryRootDependencies)
                fatalError("Cocoapods root dependencies and registry root dependencies must be known during package resolution.\nIf you see this error, you've encountered a bug.")
            }

            var constraints = cps.constraints
            for (package, versionSet) in rs.constraints {
                constraints[package] = versionSet
            }

            return .known(.init(constraints: constraints))
        }

        switch packageTypes[.init(package: package, version: version)] {
        case .registry:
            return try await registryResolver.getDependencies(package: package, version: version)
        case .cocoapods:
            return try await cocoapodsResolver.getDependencies(package: package, version: version)
        case nil:
            fatalError("WTF")
        }
    }
}
