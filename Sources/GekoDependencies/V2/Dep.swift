import Foundation
import GekoCore
import GekoCocoapods
import GekoLoader
import GekoGraph
import GekoSupport
import ProjectDescription
import PubGrub
import Collections
import Yams

struct SpecAndVersion: Hashable, Equatable {
    var name: String
    var version: PackageVersion
}

private struct UrlAndRef: Hashable {
    var url: String
    var ref: String
}

enum DependencySource: Hashable {
    case cocoapodsCdn(url: String)
    case cocoapodsGit(url: String)
    case cocoapodsFS
    case registryApi(url: String)
    case registryGit(url: String)
    // case registryGitRef(url: String, ref: ProjectDescription.RegistryDependencies.GitRef)
    case registryFS
}

enum DependencySourceSpecifier {
    case anyCocoapodsCdn
    case anyCocoapodsGit
    case cocoapodsCdn(url: String)
    case cocoapodsGit(url: String)
    case cocoapodsFS
    case anyRegistry
    case registryApi(url: String)
    case registryGit(url: String)
    case registryFS
}

class DependenciesContext {
    let projectDependencies: ProjectDescription.Dependencies

    let defaultSources: [DependencySource]
    let cocoapodsLockfile: CocoapodsLockfile?

    var cocoapodsRepoCaches: [String: CocoapodsRepoCache]
    var cocoapodsFSCache: CocoapodsFSCache
    // var cocoapodsGitRefCaches: [UrlAndRef: CocoapodsGitRefCache]
    // var cocoapodsLocalCaches: [AbsolutePath: CocoapodsLocalCache]
    //
    // var registryApiCaches: [String: RegistryApiCache]
    // var registryGitCaches: [String: RegistryGitCache]
    // var registryGitRefCaches: [UrlAndRef: RegistryGitRefCache]
    // var registryLocalCaches: [AbsolutePath: RegistryLocalCache]

    var packageDecisions: [String: DependencySourceSpecifier]
    var packageVersionDecisions: [SpecAndVersion: DependencySource]

    var availableVersionsCache: [String: [PackageVersion]]

    init(
        defaultSources: [DependencySource],
        rootDependencies: ProjectDescription.Dependencies,
        cocoapodsLockfile: CocoapodsLockfile?,
        packageDecisions: [String: DependencySourceSpecifier],
        cocoapodsRepoCaches: [String: CocoapodsRepoCache],
        cocoapodsFSCache: CocoapodsFSCache
    ) {
        self.projectDependencies = rootDependencies
        self.cocoapodsLockfile = cocoapodsLockfile
        self.defaultSources = defaultSources
        self.packageDecisions = packageDecisions
        self.cocoapodsRepoCaches = cocoapodsRepoCaches
        self.cocoapodsFSCache = cocoapodsFSCache

        // source of each version is determined during version resolution
        self.packageVersionDecisions = [:]
        self.availableVersionsCache = [:]
    }
}

func createDependenciesContext(
    for dependencies: ProjectDescription.Dependencies,
    config: Config,
    update: Bool,
    cocoapodsLockfile: CocoapodsLockfile?,
    dependenciesDirectory: AbsolutePath,
    cocoapodsCdnCacheDirectory: AbsolutePath,
    cocoapodsGitCacheDirectory: AbsolutePath,
) async throws -> DependenciesContext {
    var seenDefaultSources: Set<DependencySource> = []
    var defaultSources: [DependencySource] = []

    var seenSources: Set<DependencySource> = []
    var sources: [DependencySource] = []

    var cocoapodsRepoCaches: [String: CocoapodsRepoCache] = [:]

    // TODO: duplicate dependencies check

    if let registry = dependencies.registry {
        depLoop: for dep in registry.dependencies {
            let depSource: DependencySource

            switch dep {
            case let .remote(_name, _requirement, registry, _flavor):
                guard let registry else { continue depLoop }
                switch registry {
                case let RegistryDependencies.Registry.remote(url):
                    depSource = .registryApi(url: url)
                case let RegistryDependencies.Registry.git(url):
                    depSource = .registryGit(url: url)
                }
            case .local:
                depSource = .registryFS
            }

            if seenSources.insert(depSource).inserted {
                sources.append(depSource)
            }
        }
    }

    var localPodspecs: [(name: String, path: AbsolutePath)] = []
    var remoteGitPodspecs: [(name: String, url: String, ref: CocoapodsDependencies.GitRef)] = []

    if let cocoapods = dependencies.cocoapods {
        depLoop: for dep in cocoapods.dependencies {
            let depSource: DependencySource

            switch dep {
            case let .git(name, source, ref):
                remoteGitPodspecs.append((name: name, url: source, ref: ref))
                // depSource = DependencySource.cocoapodsGitRef(url: source, ref: ref)
                depSource = .cocoapodsFS
            case let .path(name, path):
                localPodspecs.append((name: name, path: path))
                depSource = DependencySource.cocoapodsFS
            case let .cdn(_name, _requirement, source):
                guard let source else { continue depLoop }
                depSource = DependencySource.cocoapodsCdn(url: source)
            case let .gitRepo(_name, _requirement, source):
                guard let source else { continue depLoop }
                depSource = DependencySource.cocoapodsGit(url: source)
            }

            if seenSources.insert(depSource).inserted {
                sources.append(depSource)
            }
        }
    }

    if let registry = dependencies.registry {
        for registry in registry.registries {
            switch registry {
            case let .remote(url):
                let defaultSource = DependencySource.registryApi(url: url)
                if seenDefaultSources.insert(defaultSource).inserted {
                    defaultSources.append(defaultSource)
                }
                if seenSources.insert(defaultSource).inserted {
                    sources.append(defaultSource)
                }

            case let .git(url):
                let defaultSource = DependencySource.registryGit(url: url)
                if seenDefaultSources.insert(defaultSource).inserted {
                    defaultSources.append(defaultSource)
                }
                if seenSources.insert(defaultSource).inserted {
                    sources.append(defaultSource)
                }
            }
        }
    }

    if let cocoapods = dependencies.cocoapods {
        dump(cocoapods.repos)
        for url in cocoapods.repos {
            let defaultSource = DependencySource.cocoapodsCdn(url: url)
            if seenDefaultSources.insert(defaultSource).inserted {
                defaultSources.append(defaultSource)
            }
            if seenSources.insert(defaultSource).inserted {
                sources.append(defaultSource)
            }
        }

        for url in cocoapods.gitRepos {
            let defaultSource = DependencySource.cocoapodsGit(url: url)
            if seenDefaultSources.insert(defaultSource).inserted {
                defaultSources.append(defaultSource)
            }
            if seenSources.insert(defaultSource).inserted {
                sources.append(defaultSource)
            }
        }
    }

    let cocoapodsFSCache = try await createAndInitializeCocoapodsFSCache(
        localPodspecs: localPodspecs,
        remoteGitPodspecs: remoteGitPodspecs,
        update: update,
        config: config,
        cocoapodsPathProvider: CocoapodsPathProvider(
            dependenciesDirectory: dependenciesDirectory
        )
    )

    for source in sources {
        switch source {
        case let .cocoapodsCdn(urlStr):
            dump(source)
            let cacheDir = cocoapodsCdnCacheDirectory.appending(component: reponame(for: urlStr))
            guard let url = URL(string: urlStr) else { fatalError() }
            cocoapodsRepoCaches[urlStr] = try await CocoapodsRepoCache.createAndInitializeCdnCache(
                url: url,
                cacheDir: cacheDir,
                repoUpdate: update
            )
        case let .cocoapodsGit(urlStr):
            let cacheDir = cocoapodsGitCacheDirectory.appending(component: reponame(for: urlStr))
            guard let url = URL(string: urlStr) else { fatalError() }
            cocoapodsRepoCaches[urlStr] = try await CocoapodsRepoCache.createAndInitializeGitCache(
                url: url,
                cacheDir: cacheDir,
                repoUpdate: update
            )
        case .cocoapodsFS, .registryApi, .registryGit, .registryFS:
            break
        }
    }

    let packageDecisions = constructSpecifiers(for: dependencies)

    return DependenciesContext(
        defaultSources: defaultSources,
        rootDependencies: dependencies,
        cocoapodsLockfile: cocoapodsLockfile,
        packageDecisions: packageDecisions,
        cocoapodsRepoCaches: cocoapodsRepoCaches,
        cocoapodsFSCache: cocoapodsFSCache
    )
}

func constructSpecifiers(for dependencies: ProjectDescription.Dependencies) -> [String: DependencySourceSpecifier] {
    var result: [String: DependencySourceSpecifier] = [:]

    // TODO: Throw error when duplicates

    for dep in dependencies.cocoapods?.dependencies ?? [] {
        switch dep {
        case let .cdn(name, _, url):
            if let url {
                result[name] = .cocoapodsCdn(url: url)
            } else {
                result[name] = .anyCocoapodsCdn
            }
        case let .gitRepo(name, _, url):
            if let url {
                result[name] = .cocoapodsGit(url: url)
            } else {
                result[name] = .anyCocoapodsGit
            }
        case let .git(name, _, _), let .path(name, _):
            result[name] = .cocoapodsFS
        }
    }

    for dep in dependencies.registry?.dependencies ?? [] {
        switch dep {
        case let .remote(name, _, registry, _):
            switch registry {
            case nil:
                result[name] = .anyRegistry
            case let .remote(url):
                result[name] = .registryApi(url: url)
            case let .git(url):
                result[name] = .registryGit(url: url)
            }
        case let .local(path, _):
            result[path.basenameWithoutExt] = .registryFS
        }
    }

    return result
}

extension DependenciesContext {
    func extractGraph(for resolvedPackages: [String: PackageVersion]) async throws -> DependencyGraph {
        typealias SpecsMap = [String: (
            spec: CocoapodsSpec,
            version: CocoapodsVersion,
            subspecs: Set<String>,
            source: CocoapodsSource
        )]
        var specs: SpecsMap = [:]

        for (package, version) in resolvedPackages {
            guard package != "root" else { continue }

            guard let source = packageVersionDecisions[SpecAndVersion(name: package, version: version)] else {
                fatalError()
            }

            switch source {
            case let .cocoapodsCdn(url), let .cocoapodsGit(url):
                let components = package.components(separatedBy: "/")
                let name = components[0]
                let spec = try await cocoapodsRepoCaches[url]!.spec(for: name, version: version)
                let specSource = if case .cocoapodsCdn = source {
                    CocoapodsSource.cdn(url: url)
                } else {
                    CocoapodsSource.gitRepo(url: url)
                }
            case .cocoapodsFS:
                let components = package.components(separatedBy: "/")
                let name = components[0]
                let (spec, source) = try cocoapodsFSCache.specAndSource(for: package, version: version)
            case let .registryApi(url):
                continue
            case let .registryGit(url):
                continue
            case .registryFS:
                continue
            }
        }

        return DependencyGraph(
            cocoapodsGraph: CocoapodsDependencyGraph(specs: Array(specs.values)),
            registryGraph: RegistryDependencyGraph(specs: [])
        )
    }
}

extension DependenciesContext: PubGrubDependencyProvider {
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

    func choosePackageVersion(
        potentialPackages: borrowing [(Package, VersionSet<Version>)]
    ) async throws -> (Package, Version?) {
        print("choose package version")

        assert(potentialPackages.count > 0)

        var packageVersions: [Package: AvailableVersionsSet] = [:]

        var minimalVersionsPackage = ""
        var minimalVersionsCount = Int.max

//        for (pkg, range) in potentialPackages {
        for i in 0 ..< potentialPackages.count {
            let (pkg, range) = potentialPackages[i]
            let availableVersions = try await availableVersions(for: pkg)

            var versions: [Version] = []
            for i in 0 ..< availableVersions.count {
                if range.contains(availableVersions[i]) {
                    versions.append(availableVersions[i])
                }
            }

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

            if versions.count > 0, minimalVersionsCount > versions.count {
                minimalVersionsCount = versions.count
                minimalVersionsPackage = pkg
            }
        }

        if minimalVersionsPackage == "" {
            return (packageVersions.first!.key, nil)
        }

        let speca = minimalVersionsPackage.split(separator: "/")[0]
        if let lockfileVersion = cocoapodsLockfile?.version(for: String(speca)),
            packageVersions[minimalVersionsPackage]!.contains(lockfileVersion)
        {
            return (minimalVersionsPackage, lockfileVersion)
        }

        return (minimalVersionsPackage, packageVersions[minimalVersionsPackage]!.last)
    }

    func getDependencies(
        package: String,
        version: Version
    ) async throws -> PubGrub.Dependencies<Package, Version> {
        print("getDependnecies \(package) version: \(version)")

        if package == "root" {
            return try rootDependencies()
        }

        let specAndVersion = SpecAndVersion(
            name: package,
            version: version
        )
        guard let source = packageVersionDecisions[specAndVersion] else {
            fatalError()
        }

        switch source {
        case let .cocoapodsCdn(url), let .cocoapodsGit(url):
            let cocoapodsDeps = try await cocoapodsRepoCaches[url]!.dependencies(
                for: package, version: version
            )
            let constraints = cocoapodsDeps.mapValues { $0.toVersionSet() }
            return .known(.init(constraints: constraints))
        case .cocoapodsFS:
            let cocoapodsDeps = try cocoapodsFSCache.dependencies(
                for: package, version: version
            )
            let constraints = cocoapodsDeps.mapValues { $0.toVersionSet() }
            return .known(.init(constraints: constraints))
        case .registryApi, .registryGit, .registryFS:
            return .unknown
        }
    }

    func rootDependencies() throws -> PubGrub.Dependencies<Package, Version> {
        var constraints: OrderedDictionary<Package, VersionSet<Version>> = [:]

        for dep in projectDependencies.cocoapods?.dependencies ?? [] {
            switch dep {
            case let .cdn(name, requirement, _), let .gitRepo(name, requirement, _):
                switch requirement {
                case let .exact(version):
                    guard let version = PackageVersion.parse(from: version) else {
                        throw CocoapodsVersionError.invalidVersion(
                            version, specName: name, context: "while loading Dependencies.swift"
                        )
                    }
                    constraints[name] = .exact(version: version)
                case let .atLeast(version):
                    guard let minVersion = PackageVersion.parse(from: version) else {
                        throw CocoapodsVersionError.invalidVersion(
                            version, specName: name, context: "while loading Dependencies.swift"
                        )
                    }
                    if minVersion.isPreRelease {
                        constraints[name] = .init(
                            release: .higherThan(version: minVersion.asReleaseVersion()),
                            preRelease: .exact(version: minVersion)
                        )
                    } else {
                        constraints[name] = .init(
                            release: .higherThan(version: minVersion),
                            preRelease: .none()
                        )
                    }
                case let .upToNextMinor(version):
                    guard let version = PackageVersion.parse(from: version) else {
                        throw CocoapodsVersionError.invalidVersion(
                            version, specName: name, context: "while loading Dependencies.swift"
                        )
                    }
                    let minVersion = version.asReleaseVersion()
                    let maxVersion = minVersion.bumpMinor()
                    constraints[name] = .init(
                        release: .between(minVersion, maxVersion),
                        preRelease: version.isPreRelease ? .exact(version: version) : .none()
                    )
                case let .upToNextMajor(version):
                    guard let version = CocoapodsVersion.parse(from: version) else {
                        throw CocoapodsVersionError.invalidVersion(
                            version, specName: name, context: "while loading Dependencies.swift"
                        )
                    }
                    let minVersion = version.asReleaseVersion()
                    let maxVersion = minVersion.bumpMajor()
                    constraints[name] = .init(
                        release: .between(minVersion, maxVersion),
                        preRelease: version.isPreRelease ? .exact(version: version) : .none()
                    )
                }
            case let .git(name, _, _):
                guard let version = cocoapodsFSCache.version(of: name) else {
                    fatalError("")
                }
                constraints[name] = .exact(version: version)
            case let .path(name, _):
                guard let version = cocoapodsFSCache.version(of: name) else {
                    fatalError("")
                }
                constraints[name] = .exact(version: version)
            }
        }

        for dep in projectDependencies.registry?.dependencies ?? [] {
            switch dep {
            // TODO:
            default:
                break
            }
        }

        return .known(.init(constraints: constraints))
    }

    func availableVersions(for pkg: String) async throws -> [Version] {
        if pkg == "root" {
            return [PackageVersion(1, 0, 0)]
        }

        if let cached = availableVersionsCache[pkg] {
            return cached
        }

        var sourcesToLookup: [DependencySource] = []

        switch packageDecisions[pkg] {
        case nil:
            sourcesToLookup = defaultSources

        case .anyCocoapodsCdn:
            for source in defaultSources {
                if case .cocoapodsCdn = source {
                    sourcesToLookup.append(source)
                }
            }

        case .anyCocoapodsGit:
            for source in defaultSources {
                if case .cocoapodsGit = source {
                    sourcesToLookup.append(source)
                }
            }

        case let .cocoapodsCdn(url):
            sourcesToLookup.append(.cocoapodsCdn(url: url))

        case let .cocoapodsGit(url):
            sourcesToLookup.append(.cocoapodsGit(url: url))

        case .cocoapodsFS:
            sourcesToLookup.append(.cocoapodsFS)
        case .anyRegistry:
            break
        case let .registryApi(_url):
            break
        case let .registryGit(_url):
            break
        case .registryFS:
            break
        }

        var versions: Set<Version> = []

        for source in sourcesToLookup {
            let sourceVersions: [Version]

            switch source {
            case let .cocoapodsCdn(url), let .cocoapodsGit(url):
                let specName = pkg.components(separatedBy: "/")[0]
                sourceVersions = try await cocoapodsRepoCaches[url]?.availableVersions(for: specName) ?? []
            case .cocoapodsFS:
                let specName = pkg.components(separatedBy: "/")[0]
                sourceVersions = cocoapodsFSCache.availableVersions(of: specName)
            case .registryApi, .registryGit, .registryFS:
                sourceVersions = []
            }

            versions.formUnion(sourceVersions)
            for version in sourceVersions {
                let specAndVersion = SpecAndVersion(name: pkg, version: version)
                if packageVersionDecisions[specAndVersion] == nil {
                    packageVersionDecisions[specAndVersion] = source
                }
            }
        }

        let result = versions.sorted()
        availableVersionsCache[pkg] = result

        return result
    }
}
