import Collections
import Foundation
import ProjectDescription
import PubGrub
import GekoCore
import GekoLoader
import GekoGraph
import GekoRegistry
import GekoSupport

class RegistryResolver {
    private let dependencies: Registry

    private let jsonDecoder = JSONDecoder()

    private let packages: [RegistryPackage]

    init(dependencies: Registry, generatorPaths: GeneratorPaths) throws {
        self.dependencies = dependencies

        var packages: [RegistryPackage] = []

        for dependency in dependencies.dependencies {
            switch dependency {
            case let .local(path):
                let path = try generatorPaths.resolve(path: path)
                let data = try FileHandler.shared.readFile(path)
                let package = try jsonDecoder.decode(RegistryPackage.self, from: data)
                packages.append(package)
                print("package \(package.name) has been loaded")
            }
        }

        self.packages = packages
    }
}

extension RegistryResolver: PubGrubDependencyProvider {
    typealias Package = String
    typealias Version = ProjectDescription.PackageVersion

    private struct AvailableVersionsSet {
        var release: [Version] = []
        var preRelease: [Version] = []

        var last: Version? {
            return release.last ?? preRelease.last
        }

        func contains(_ version: Version) -> Bool {
            return release.contains(version) || preRelease.contains(version)
        }
    }

    func availableVersions(for pkg: String) async throws -> [Version] {
        // if package == rootName {
        if pkg == "root" {
            return [PackageVersion(1, 0, 0)]
        }

        guard let package = self.packages.first(where: { $0.name == pkg }) else {
            return []
        }

        return [package.version]
    }

    func choosePackageVersion(
        potentialPackages: [(Package, VersionSet<Version>)]
    ) async throws -> (Package, Version?) {
        assert(potentialPackages.count > 0)

        var packageVersions: [Package: AvailableVersionsSet] = [:]

        var minimalVersionsPackage = ""
        var minimalVersionsCount = Int.max

        for (pkg, range) in potentialPackages {
            let versions = try await availableVersions(for: pkg).filter { v in range.contains(v) }
            var set = AvailableVersionsSet()
            for v in versions {
                if v.isPreRelease {
                    set.preRelease.append(v)
                } else {
                    set.release.append(v)
                }
                set.preRelease.sort()
                set.release.sort()
            }
            packageVersions[pkg] = set

            if minimalVersionsCount > versions.count {
                minimalVersionsCount = versions.count
                minimalVersionsPackage = pkg
            }
        }

        return (minimalVersionsPackage, packageVersions[minimalVersionsPackage]!.last)
    }

    func getDependencies(
        package: String,
        version: Version
    ) async throws -> PubGrub.Dependencies<Package, Version> {
        if package == "root" {
            var constraints: OrderedDictionary<Package, VersionSet<Version>> = [:]

            for package in packages {
                constraints[package.name] = .exact(version: package.version)
            }

            return .known(.init(constraints: constraints))
        }

        guard let package = packages.first(where: { $0.name == package && $0.version == version }) else {
            return .unknown
        }

        var constraints: OrderedDictionary<Package, VersionSet<Version>> = [:]
        for dep in package.dependencies {
            constraints[dep.name] = dep.requirement.toVersionSet()
        }

        return .known(.init(constraints: constraints))
    }

    func resolve(packages: [String: PackageVersion]) async throws -> RegistryDependencyGraph {
        var result: RegistryDependencyGraph = .init(specs: [])

        for kv in packages {
            let (package, version) = kv

            guard package != "root" else { continue }

            guard let spec = self.packages.first(where: { $0.name == package && $0.version == version }) else {
                fatalError("fatal errure, name: \(package), version: \(version)")
            }

            result.specs.append(spec)
        }

        return result
    }
}
