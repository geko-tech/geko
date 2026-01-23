import Collections
import Foundation
import GekoCocoapods
import GekoGraph
import GekoSupport
import ProjectDescription
import PubGrub

extension String: PubGrub.Package {
    public var name: String {
        self
    }
}

enum CocoapodsDependenciesResolverError: FatalError, CustomStringConvertible {
    case noSolution(String)

    var type: ErrorType { .abort }

    var description: String {
        switch self {
        case let .noSolution(message):
            return "Package resolution failed:\n\n" + message
        }
    }
}

class CocoapodsDependenciesResolver {
    typealias Package = String
    typealias Version = CocoapodsVersion
    typealias DependenciesMap = [String: CocoapodsDependencies.Dependency]
    typealias PrefetchSpec = (specName: String, version: CocoapodsVersion, source: String)

    private let repoInteractorCdn: CocoapodsRepoInteractor
    private let repoInteractorGit: CocoapodsRepoInteractor
    private let gitInteractor: CocoapodsGitInteractor
    private let pathInteractor: CocoapodsPathInteractor
    private let rootDependencies: [String: CocoapodsDependencies.Dependency]
    private let lockfile: CocoapodsLockfile?

    private let rootName = "root"

    private var availablePackageVersionsCache: [Package: [Version]] = [:]

    init(
        lockfile: CocoapodsLockfile?,
        repoInteractorCdn: CocoapodsRepoInteractor,
        repoInteractorGit: CocoapodsRepoInteractor,
        gitInteractor: CocoapodsGitInteractor,
        pathInteractor: CocoapodsPathInteractor,
        dependencies: CocoapodsDependencies
    ) {
        self.lockfile = lockfile
        self.repoInteractorCdn = repoInteractorCdn
        self.repoInteractorGit = repoInteractorGit
        self.gitInteractor = gitInteractor
        self.pathInteractor = pathInteractor
        rootDependencies = dependencies.dependencies.reduce(into: DependenciesMap()) { acc, value in
            acc[value.name] = value
        }
    }

    func resolve() async throws -> CocoapodsDependencyGraph {
        if let lockfile {
            try await prefetchSpecs(lockfile: lockfile)
        }

        let resolver = PubGrubSolver(dependencyProvider: self)

        let clock = SuspendingClock()
        let startTime = clock.now

        let resolvedPackages: [Package: Version]
        do {
            resolvedPackages = try await resolver.resolve(package: rootName, version: CocoapodsVersion(1, 0, 0))
        } catch let PubGrubError<Package, Version>.noSolution(derivationTree) {
            throw CocoapodsDependenciesResolverError.noSolution(
                DefaultStringReporter.report(derivationTree: derivationTree, colored: Environment.shared.shouldOutputBeColoured)
            )
        }

        let timeElapsed = clock.now - startTime

        if logger.logLevel == .debug {
            logger.debug("------------------------------------------")
            logger.debug("Resolution ended. Took \(timeElapsed)")
            logger.debug("Resolved packages:")
            for p in resolvedPackages.keys.sorted() {
                let v = resolvedPackages[p]!
                logger.debug("\(p): \(v)")
            }
            logger.debug("------------------------------------------")
        }

        typealias SpecsMap = [String: (
            spec: CocoapodsSpec,
            version: CocoapodsVersion,
            subspecs: Set<String>,
            source: CocoapodsSource
        )]
        var specs: SpecsMap = [:]

        for kv in resolvedPackages {
            let (package, version) = kv
            let components = package.components(separatedBy: "/")
            let name = components[0]
            guard name != rootName else {
                continue
            }

            if specs[name] == nil {
                let spec: (spec: CocoapodsSpec, source: CocoapodsSource)
                if gitInteractor.contains(name) {
                    spec = gitInteractor.spec(for: name)
                } else if pathInteractor.contains(name) {
                    spec = pathInteractor.spec(for: name)
                } else {
                    switch rootDependencies[name] {
                    case let .cdn(_, _, source):
                        spec = try await repoInteractorCdn.spec(
                            for: name,
                            version: version,
                            source: source
                        )
                    case let .gitRepo(_, _, source):
                        spec = try await repoInteractorGit.spec(
                            for: name,
                            version: version,
                            source: source
                        )
                    case .none:
                        do {
                            spec = try await repoInteractorCdn.spec(
                                for: name,
                                version: version,
                                source: nil
                            )
                        } catch CocoapodsRepoInteractorError.specNotFound {
                            spec = try await repoInteractorGit.spec(
                                for: name,
                                version: version,
                                source: nil
                            )
                        }
                    case .path, .git:
                        // Impossible cases
                        continue
                    }
                }

                specs[name] = (spec.spec, version, [], spec.source)
            }

            if components.count > 1 {
                let subspec = components[1...].joined(separator: "/")
                specs[name]!.subspecs.insert(subspec)
            }
        }

        if logger.logLevel <= .debug {
            for values in specs.values {
                let spec = values.spec
                let subspecs = values.subspecs

                logger.debug("\(spec.name)")
                for subspec in subspecs {
                    logger.debug("    \(subspec)")
                }
            }
        }

        return .init(specs: Array(specs.values))
    }

    private func availableVersions(for package: String) async throws -> [Version] {
        if package == rootName {
            return [CocoapodsVersion(1, 0, 0)]
        }

        if let cached = availablePackageVersionsCache[package] {
            return cached
        }

        let base = package.components(separatedBy: "/").first!

        let result: [Version]

        if let dep = rootDependencies[base] {
            switch dep {
            case let .cdn(_, requirement, source):
                result = try await repoInteractorCdn.availableVersions(for: base, requirement: requirement, source: source)
            case let .gitRepo(_, requirement, source):
                result = try await repoInteractorGit.availableVersions(for: base, requirement: requirement, source: source)
            case let .git(name, _, _):
                let version = gitInteractor.version(of: name)
                result = [version]
            case let .path(name, _):
                let version = pathInteractor.version(of: name)
                result = [version]
            }
        } else {
            if gitInteractor.contains(base) {
                result = [gitInteractor.version(of: base)]
            } else {
                async let cdnAvailableVersionsTask = repoInteractorCdn.availableVersions(for: base)
                async let gitAvailableVersionsTask = repoInteractorGit.availableVersions(for: base)

                let cdnAvailableVersions = try await cdnAvailableVersionsTask
                let gitAvailableVersions = try await gitAvailableVersionsTask

                switch (cdnAvailableVersions.isEmpty, gitAvailableVersions.isEmpty) {
                case (true, true):
                    result = []
                case (false, true):
                    result = cdnAvailableVersions
                case (true, false):
                    result = gitAvailableVersions
                case (false, false):
                    result = sortedAndUniqued(cdnAvailableVersions + gitAvailableVersions)
                }
            }
        }

        availablePackageVersionsCache[package] = result

        return result
    }

    private func sortedAndUniqued(_ versions: [CocoapodsVersion]) -> [CocoapodsVersion] {
        var seen = Set<CocoapodsVersion>()
        return versions
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    private func prefetchSpecs(lockfile: CocoapodsLockfile) async throws {
        let prefetchSpecs: [PrefetchSpec] = lockfile
            .podsBySource
            .filter { _, sourceData in sourceData.type == .cdn }
            .flatMap { (source, sourceData) in
                sourceData.pods.map { specName, podData in
                    PrefetchSpec(specName, podData.version, source)
                }
            }

        // this line crashes https://github.com/swiftlang/swift-corelibs-foundation/blob/main/Sources/FoundationNetworking/URLSession/libcurl/EasyHandle.swift#L822
        // when using concurrency on Linux
        #if os(Linux)
        let concurrentTasksCount = 1
        #else
        let concurrentTasksCount = ProcessInfo.processInfo.processorCount
        #endif

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            var idx = 0

            func addTask(spec: PrefetchSpec) {
                taskGroup.addTask { [spec] in
                    _ = try? await self.repoInteractorCdn.spec(
                        for: spec.specName, version: spec.version, source: spec.source
                    )
                }
                idx += 1
            }

            while idx < min(concurrentTasksCount, prefetchSpecs.count) {
                addTask(spec: prefetchSpecs[idx])
            }

            for try await _ in taskGroup {
                if idx < prefetchSpecs.count {
                    addTask(spec: prefetchSpecs[idx])
                }
            }
        }
    }
}

extension CocoapodsDependenciesResolver: PubGrubDependencyProvider {
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
        potentialPackages: [(Package, VersionSet<Version>)]
    ) async throws -> (Package, Version?) {
        assert(potentialPackages.count > 0)

        var packageVersions: [Package: AvailableVersionsSet] = [:]

        var minimalVersionsPackage = ""
        var minimalVersionsCount = Int.max

        for (pkg, range) in potentialPackages {
            let versions = try await availableVersions(for: pkg)
                .filter { v in range.contains(v) }
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

        if let lockfileVersion = lockfile?.version(for: minimalVersionsPackage),
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
        if package == "root" {
            var constraints: OrderedDictionary<Package, VersionSet<Version>> = [:]
            for dep in rootDependencies.values {
                switch dep {
                case let .cdn(name, requirement, _), let .gitRepo(name, requirement, _):
                    switch requirement {
                    case let .exact(version):
                        guard let version = CocoapodsVersion.parse(from: version) else {
                            throw CocoapodsVersionError.invalidVersion(
                                version, specName: name, context: "while loading Dependencies.swift"
                            )
                        }
                        constraints[name] = .exact(version: version)
                    case let .atLeast(version):
                        guard let minVersion = CocoapodsVersion.parse(from: version) else {
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
                        guard let version = CocoapodsVersion.parse(from: version) else {
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
                    let version = gitInteractor.version(of: name)
                    constraints[name] = .exact(version: version)
                case let .path(name, _):
                    let version = pathInteractor.version(of: name)
                    constraints[name] = .exact(version: version)
                }
            }
            return .known(.init(constraints: constraints))
        }

        let specName = package.components(separatedBy: "/")[0]
        if let dep = rootDependencies[specName] {
            switch dep {
            case let .cdn(_, _, source):
                let constraints = try await repoInteractorCdn.dependencies(
                    for: package, version: version, source: source
                ).mapValues { $0.toVersionSet() }

                return .known(.init(constraints: constraints))
            case .git:
                let deps = try gitInteractor.dependencies(of: package).mapValues { $0.toVersionSet() }
                return .known(.init(constraints: deps))
            case .path:
                let deps = try pathInteractor.dependencies(of: package).mapValues { $0.toVersionSet() }
                return .known(.init(constraints: deps))
            case let .gitRepo(_, _, source):
                let constraints = try await repoInteractorGit.dependencies(
                    for: package, version: version, source: source
                ).mapValues { $0.toVersionSet() }

                return .known(.init(constraints: constraints))
            }
        } else {
            if gitInteractor.contains(specName) {
                let deps = try gitInteractor.dependencies(of: package).mapValues { $0.toVersionSet() }
                return .known(.init(constraints: deps))
            } else if pathInteractor.contains(specName) {
                let deps = try pathInteractor.dependencies(of: package).mapValues { $0.toVersionSet() }
                return .known(.init(constraints: deps))
            } else {
                let dependencies: OrderedDictionary<String, CocoapodsVersionRange>

                do {
                    dependencies = try await repoInteractorCdn.dependencies(for: package, version: version)
                } catch CocoapodsRepoInteractorError.specNotFound {
                    dependencies = try await repoInteractorGit.dependencies(for: package, version: version)
                }

                return .known(
                    .init(
                        constraints: dependencies.mapValues { $0.toVersionSet() }
                    )
                )
            }
        }
    }

    func shouldCancel() throws {}
}

extension CocoapodsVersionRange {
    fileprivate func toVersionSet() -> VersionSet<CocoapodsVersion> {
        switch self {
        case .any:
            return .any()
        case let .exact(version):
            if version.isPreRelease {
                return .init(
                    release: .exact(version: version.asReleaseVersion()),
                    preRelease: .exact(version: version)
                )
            }

            return .init(
                release: .exact(version: version),
                // any pre-release version is suitable as long it has the same non-pre-release components
                preRelease: .between(version.withEmptyPreRelease(), version)
            )

        case let .higherThan(version):
            if version.isPreRelease {
                let rv = version.asReleaseVersion()
                return .init(
                    release: .higherThan(version: rv),
                    preRelease: .between(version, rv)
                )
            }

            return .init(
                release: .higherThan(version: version),
                preRelease: .higherThan(version: version.withEmptyPreRelease())
            )

        case let .strictlyLessThan(version):
            return .init(
                release: .strictlyLowerThan(version: version.asReleaseVersion()),
                preRelease: .strictlyLowerThan(version: version)
            )

        case let .between(min, max):
            // pre-release ranges are not supported
            let max = max.asReleaseVersion()

            if min.isPreRelease {
                return .init(
                    release: .between(min.asReleaseVersion(), max),
                    preRelease: .between(min, max)
                )
            }

            return .init(
                release: .between(min, max),
                preRelease: .between(min.withEmptyPreRelease(), max)
            )
        }
    }
}

//extension String: Comparable {
//    static func < (lhs: String, rhs: String) -> Bool {
//        return lhs.compare(rhs) == .orderedAscending
//    }
//}
