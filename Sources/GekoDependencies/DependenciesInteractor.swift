import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoLoader
import GekoGraph
import GekoSupport
import Yams

class DependenciesInteractor {
    // private let cocoapodsInteractor = CocoapodsInteractor()

    public func install(
        path: AbsolutePath,
        dependenciesDirectory: AbsolutePath,
        generatorPaths: GeneratorPaths,
        config: Config,
        dependencies: Dependencies,
        shouldUpdate: Bool,
        repoUpdate: Bool,
        deployment: Bool
    ) async throws -> GekoCore.DependenciesGraph {
        let pathProvider = try CocoapodsPathProvider(
            dependenciesDirectory: dependenciesDirectory
        )

        let lockfilePath = pathProvider.lockfilePath
        var lockfile: CocoapodsLockfile? = nil
        if !shouldUpdate, FileHandler.shared.exists(lockfilePath) {
            do {
                lockfile = try CocoapodsLockfile.load(from: lockfilePath)
            } catch {
                logger.warning("Cocoapods.lock file is damaged")
            }
        }

        let (cdnRepos, gitRepos) = try createRepos(for: dependencies.cocoapods!, repoUpdate: repoUpdate, pathProvider: pathProvider)
        let gitSources = createGitSources(for: dependencies.cocoapods!)

        let gitInteractor = CocoapodsGitInteractor(
            config: config,
            sources: gitSources,
            pathProvider: pathProvider
        )
        let repoInteractorCdn = CocoapodsRepoInteractor(
            repos: cdnRepos,
            repoPriority: dependencies.cocoapods!.repos,
            sourceFactory: { .cdn(url: $0) }
        )
        let repoInteractorGit = CocoapodsRepoInteractor(
            repos: gitRepos,
            repoPriority: dependencies.cocoapods!.gitRepos,
            sourceFactory: { .gitRepo(url: $0) }
        )
        let pathInteractor = CocoapodsPathInteractor(
            path: path,
            generatorPaths: generatorPaths,
            manifestConfig: config,
            pathConfigs: createPathConfigs(for: dependencies.cocoapods!)
        )

        let cocoapodsResolver = CocoapodsDependenciesResolver(
            lockfile: lockfile,
            repoInteractorCdn: repoInteractorCdn,
            repoInteractorGit: repoInteractorGit,
            gitInteractor: gitInteractor,
            pathInteractor: pathInteractor,
            dependencies: dependencies.cocoapods!
        )

        let registryResolver = try RegistryResolver(
            dependencies: dependencies.registry!,
            generatorPaths: generatorPaths
        )

        let resolver = DependenciesResolver(
            cocoapodsResolver: cocoapodsResolver,
            registryResolver: registryResolver
        )

        // first we need to download git dependencies to be able to gather information from podspec
        try await gitInteractor.downloadAndCache()
        try await downloadGitRepos(gitRepos: dependencies.cocoapods!.gitRepos, config: config, pathProvider: pathProvider, repoUpdate: repoUpdate)

        // get specs from local paths
        try pathInteractor.obtainSpecs()

        let dependenciesGraph = try await resolver.resolve()
        let newLockfile = CocoapodsLockfile.from(dependenciesGraph: dependenciesGraph.cocoapodsGraph)

        dump(dependenciesGraph)
        exit(0)

        logger.info("Installing Cocoapods dependencies", metadata: .subsection)
        let downloader = CocoapodsDependencyDownloader(
            pathProvider: pathProvider
        )
        let installer = try CocoapodsDependenciesInstaller(
            gitInteractor: gitInteractor,
            downloader: downloader,
            pathInteractor: pathInteractor,
            pathProvider: pathProvider
        )

        var graph = try await installer.install(
            dependencies: dependenciesGraph.cocoapodsGraph,
            defaultForceLinking: dependencies.cocoapods!.defaultForceLinking,
            forceLinking: dependencies.cocoapods!.forceLinking ?? [:]
        )

        let registryGraph = try await RegistryDependenciesInstaller(pathProvider: pathProvider)
            .install(dependencies: dependenciesGraph.registryGraph)

        try graph = graph.merging(with: registryGraph)

        if deployment {
            guard let lockfile else {
                throw CocoapodsInteractorError.missingLockfileInDeployment
            }

            try lockfile.compare(to: newLockfile)
        }
        try newLockfile.write(to: lockfilePath)

        let cleanupService = CocoapodsCleanupService(pathProvider: pathProvider)
        try cleanupService.cleanup()

        try? save(dependencies: dependencies.cocoapods!, lockfile: newLockfile, path: FileHandler.shared.currentPath)

        return graph
    }

    public func clean(dependenciesDirectory _: AbsolutePath) throws {
        logger.info("Cleaning up Cocoapods dependencies")
    }

    public func needFetch(dependencies: CocoapodsDependencies, path: AbsolutePath) throws -> Bool {
        let clock = WallClock()
        let timer = clock.startTimer()

        let sandboxLockfileFilePath = path.appending(component: Constants.GekoUserCacheDirectory.name)
            .appending(component: Constants.DependenciesDirectory.cocoapodsSandboxName)

        guard FileHandler.shared.exists(sandboxLockfileFilePath) else {
            return true
        }

        let pathProvider = try CocoapodsPathProvider(
            dependenciesDirectory: path.appending(component: Constants.gekoDirectoryName)
                .appending(component: Constants.DependenciesDirectory.name)
        )
        let lockfilePath = pathProvider.lockfilePath
        guard let lockfile = try? CocoapodsLockfile.load(from: lockfilePath) else {
            logger.debug("CocoapodsSandbox.lock is not present. Fetching...")
            return true
        }
        let currentDependencies = CocoapodsDependenciesSandbox(dependencies: dependencies, lockfile: lockfile)

        let oldDependeciesData = try FileHandler.shared.readTextFile(sandboxLockfileFilePath)
        let oldDependecies = try YAMLDecoder().decode(CocoapodsDependenciesSandbox.self, from: oldDependeciesData)

        let result = currentDependencies != oldDependecies

        if result {
            logger.debug("CocoapodsSandbox.lock does not match requested dependencies. Fetching...")
        } else {
            logger.debug("CocoapodsSandbox.lock matches requested dependencies. Skipping fetch.")
        }

        logger.debug("Cocoapods needFetch check time: \(timer.stop())")

        return result
    }

    private func save(dependencies: CocoapodsDependencies, lockfile: CocoapodsLockfile, path: AbsolutePath) throws {
        let currentDependencies = try sandboxData(from: dependencies, lockfile: lockfile)

        let sandboxLockfileFilePath = path.appending(component: Constants.GekoUserCacheDirectory.name)
            .appending(component: Constants.DependenciesDirectory.cocoapodsSandboxName)

        try FileHandler.shared.write(currentDependencies, path: sandboxLockfileFilePath, atomically: true)
    }

    private func sandboxData(
        from dependencies: CocoapodsDependencies,
        lockfile: CocoapodsLockfile
    ) throws -> String {
        let model = CocoapodsDependenciesSandbox(dependencies: dependencies, lockfile: lockfile)

        let encoder = YAMLEncoder()
        encoder.options.sortKeys = true

        return try encoder.encode(model)
    }
}

// MARK: - Repo

extension DependenciesInteractor {
    private func createRepos(
        for deps: CocoapodsDependencies,
        repoUpdate: Bool,
        pathProvider: CocoapodsPathProviding
    ) throws -> (cdnRepos: [String: CocoapodsRepo], gitRepos: [String: CocoapodsRepo]) {
        var cdnRepos: [String: CocoapodsRepo] = [:]
        var gitRepos: [String: CocoapodsRepo] = [:]

        let cdnRepoFactory: (String) throws -> CocoapodsRepo = { source in
            guard let url = URL(string: source) else {
                throw CocoapodsInteractorError.invalidRepoUrl(source)
            }
            return CocoapodsRepo(
                source: url,
                repoUpdate: repoUpdate,
                pathProvider: pathProvider,
                cocoapodsRepoDataProvider: CocoapodsRepoDataProviderCdn()
            )
        }
        let gitRepoFactory: (String) throws -> CocoapodsRepo = { source in
            guard let url = URL(string: source) else {
                throw CocoapodsInteractorError.invalidRepoUrl(source)
            }
            return CocoapodsRepo(
                source: url,
                repoUpdate: repoUpdate,
                pathProvider: pathProvider,
                cocoapodsRepoDataProvider: CocoapodsRepoDataProviderGit()
            )
        }

        for repo in deps.repos {
            guard cdnRepos[repo] == nil else { continue }
            cdnRepos[repo] = try cdnRepoFactory(repo)
        }

        for gitRepo in deps.gitRepos {
            guard gitRepos[gitRepo] == nil else { continue }
            gitRepos[gitRepo] = try gitRepoFactory(gitRepo)
        }

        for dependency in deps.dependencies {
            switch dependency {
            case let .cdn(_, _, source):
                guard let source, cdnRepos[source] == nil else { break }
                cdnRepos[source] = try cdnRepoFactory(source)
            case let .gitRepo(_, _, source):
                guard let source, gitRepos[source] == nil else { break }
                gitRepos[source] = try gitRepoFactory(source)
            default:
                break
            }
        }

        return (cdnRepos, gitRepos)
    }

    private func createGitSources(
        for deps: CocoapodsDependencies
    ) -> [CocoapodsGitInteractor.Source] {
        var sources: [CocoapodsGitInteractor.Source] = []

        for dependency in deps.dependencies {
            switch dependency {
            case let .git(name, source, ref):
                sources.append(.init(source: source, name: name, ref: ref))
            default:
                break
            }
        }

        return sources
    }

    private func createPathConfigs(for deps: CocoapodsDependencies) -> [CocoapodsPathInteractor.PathConfig] {
        return deps.dependencies.compactMap { dependency in
            if case let .path(name, path) = dependency {
                return .init(name: name, path: path)
            }
            return nil
        }
    }

    private func downloadGitRepos(
        gitRepos: [String],
        config: Config,
        pathProvider: CocoapodsPathProvider,
        repoUpdate: Bool
    ) async throws {
        for source in gitRepos {
            let downloader = CocoapodsRepoGitSourceUpdater(
                config: config,
                source: source,
                repoUpdate: repoUpdate,
                pathProvider: pathProvider
            )

            try await downloader.download()
        }
    }
}
