import Foundation
import GekoCocoapods
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

struct PodspecTargetDependency: Hashable {
    var target: Target
    var dependencies: [String]
}

public protocol CocoapodsPodspecLoading {
    func load(
        config: Config,
        workspace: Workspace,
        gekoProjects: [Project],
        externalDependencies: [String: [TargetDependency]],
        defaultForceLinking: CocoapodsDependencies.Linking?,
        forceLinking: [String : CocoapodsDependencies.Linking],
        sideTable: inout GraphSideTable
    ) async throws -> ([Project], [SideEffectDescriptor])
}

enum CocoapodsPodspecLoaderError: FatalError {
    case notFoundTargetDependencies([String: [String]])
    case duplicatePodspec(AbsolutePath, AbsolutePath)

    var type: GekoSupport.ErrorType { .abort }

    var description: String {
        switch self {
        case let .notFoundTargetDependencies(targets):
            return "Could not find dependencies for targets: \(targets)"
        case let .duplicatePodspec(first, second):
            return "Found duplicate podspecs\n\(first)\n\(second)"
        }
    }
}

public class CocoapodsPodspecLoader: CocoapodsPodspecLoading {
    // MARK: - Attributes

    private let projectGenerator = CocoapodsProjectGenerator()
    private let podspecConverter: CocoapodsPodspecConverting
    private let cocoapodsLocationProvider: CocoapodsLocationProviding
    private let gekoPluginStorage: GekoPluginStoring

    // MARK: - Intialization

    public init(
        cocoapodsLocationProvider: CocoapodsLocationProviding = CocoapodsLocationProvider(),
        podspecConverter: CocoapodsPodspecConverting = CocoapodsPodspecConverter(),
        gekoPluginStorage: GekoPluginStoring = GekoPluginStorage.shared
    ) {
        self.cocoapodsLocationProvider = cocoapodsLocationProvider
        self.podspecConverter = podspecConverter
        self.gekoPluginStorage = gekoPluginStorage
    }

    // MARK: - CocoapodsPodspecLoading

    public func load(
        config: Config,
        workspace: Workspace,
        gekoProjects: [Project],
        externalDependencies: [String: [TargetDependency]],
        defaultForceLinking: CocoapodsDependencies.Linking?,
        forceLinking: [String : CocoapodsDependencies.Linking],
        sideTable: inout GraphSideTable
    ) async throws -> ([Project], [SideEffectDescriptor]) {
        let paths = loadPodspecMapping(
            from: workspace.generationOptions.autogenerateLocalPodsProjects
        )

        guard !paths.isEmpty else {
            return ([], [])
        }

        let testPlansByTarget = try CocoapodsXCTestPlanLoader().loadXCTestPlans(
            testPlanPaths: workspace.generationOptions.autogenerateLocalPodsSchemes.testPlans
        )

        let projectOptionsProvider = CocoapodsProjectOptionsProvider(
            workspaceGenerationOptions: workspace.generationOptions,
            testPlansByTarget: testPlansByTarget
        )

        var gekoProjectsDict: [String: Project] = [:]
        gekoProjects.forEach { gekoProjectsDict[$0.name] = $0 }

        let podspecs = try loadPodspec(paths: paths, config: config)
        var sideEffects: [SideEffectDescriptor] = []

        let appHostDependencyResolver = CocoapodsApphostDependencyResolver(
            localPodspecNameToPath: podspecs.reduce(into: [:], { $0[$1.podspec.name] = $1.path }),
            externalDependencies: externalDependencies
        )

        let tempSideTable = Atomic(wrappedValue: GraphSideTable())

        let projects = try await podspecs.concurrentMap { [projectGenerator, tempSideTable] v in
            try projectGenerator.generateProject(
                spec: v.podspec,
                path: v.path,
                podspecPath: v.podspecPath,
                workspacePath: workspace.path,
                externalDependencies: externalDependencies,
                appHostDependencyResolver: appHostDependencyResolver,
                projectOptionsProvider: projectOptionsProvider,
                convertPathsToBuildableFolders: config.generationOptions.convertPathsInPodspecsToBuildableFolders,
                defaultForceLinking: defaultForceLinking,
                forceLinking: forceLinking,
                sideTable: tempSideTable
            )
        }
        .reduce(into: [String: Project]()) { acc, project in
            sideEffects += project.1

            guard acc[project.0.name] == nil else {
                throw CocoapodsPodspecLoaderError.duplicatePodspec(
                    project.0.podspecPath!,
                    acc[project.0.name]!.podspecPath!)
            }

            acc[project.0.name] = project.0
        }

        tempSideTable.wrappedValue.workspace.projects.forEach { path, project in
            project.targets.forEach { targetName, targetSideTable in
                sideTable.setSources(targetSideTable.sources, path: path, name: targetName)
                sideTable.setResources(targetSideTable.resources, path: path, name: targetName)
            }
        }

        return (Array(projects.values), sideEffects)
    }
}

// MARK: - Parse podspecs

extension CocoapodsPodspecLoader {
    private func loadPodspecMapping(
        from manifest: Workspace.GenerationOptions.AutogenerateLocalPodsProjects
    ) -> [AbsolutePath: AbsolutePath] {
        switch manifest {
        case .disabled: 
            return [:]
        case .automatic(let paths, nil):
            let projectPaths: [AbsolutePath] = paths.map { path -> AbsolutePath in
                return AbsolutePath(stringLiteral: path.pathString.replacing(#/\.podspec(?:\.json)?$/#, with: ""))
            }
            return  Dictionary(uniqueKeysWithValues: zip(paths, projectPaths))
        case let .automatic(paths, base):
            let projectPaths = paths.map {
                base!.appending(component: $0.basenameWithoutExt)
            }
            return Dictionary(uniqueKeysWithValues: zip(paths, projectPaths))
        case let .manual(paths):
            return paths
        }
    }

    private func loadPodspec(
        paths: [AbsolutePath: AbsolutePath],
        config: Config
    ) throws -> [(path: AbsolutePath, podspecPath: AbsolutePath, podspec: CocoapodsSpec)] {

        var pathPodspecsTriples: [(AbsolutePath, AbsolutePath, CocoapodsSpec)] = []

        let rawTuples = try podspecConverter.convert(
            paths: paths.keys.map { $0.pathString },
            shellCommand: try cocoapodsLocationProvider.shellCommand(config: config)
        )

        for (podspecPath, data) in rawTuples {
            let podspecAbsolutePath = try AbsolutePath(validatingAbsolutePath: podspecPath)
            let podspec: CocoapodsSpec = try parseJson(data, context: .podspec(path: podspecAbsolutePath))
            pathPodspecsTriples.append((paths[podspecAbsolutePath]!, podspecAbsolutePath, podspec))
        }

        return pathPodspecsTriples
    }
}
