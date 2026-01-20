import Foundation
import GekoCore
import GekoGenerator
import GekoGraph
import GekoLoader
import GekoPlugin
import GekoSupport
import ProjectAutomation
import ProjectDescription

final class GraphService {
    private let manifestGraphLoader: ManifestGraphLoading

    convenience init(keepGlobs: Bool) {
        var workspaceMappers: [WorkspaceMapping] = [
            ReplaceLocalReferencesWorkspaceMapper(),
            ResolvePathsWorkspaceMapper(),
            WorkspaceMapperPluginExecutor(stage: .rawGlobs)
        ]

        if !keepGlobs {
            workspaceMappers.append(
                ResolveGlobsWorkspaceMapper(checkFilesExist: true)
            )
            workspaceMappers.append(
                WorkspaceMapperPluginExecutor(stage: .resolvedGlobs)
            )
            workspaceMappers.append(
                ResolveTargetRulesWorkspaceMapper()
            )
        }

        let manifestLoader = ManifestLoaderFactory()
            .createManifestLoader()
        let manifestGraphLoader = ManifestGraphLoader(
            manifestLoader: manifestLoader,
            workspaceMapper: SequentialWorkspaceMapper(mappers: workspaceMappers),
            graphMapper: SequentialGraphMapper([])
        )
        self.init(
            manifestGraphLoader: manifestGraphLoader
        )
    }

    init(
        manifestGraphLoader: ManifestGraphLoading
    ) {
        self.manifestGraphLoader = manifestGraphLoader
    }

    func run(
        format: GraphFormat,
        skipTestTargets: Bool,
        skipExternalDependencies: Bool,
        open: Bool,
        platformToFilter: Platform?,
        targetsToFilter: [String],
        path: AbsolutePath,
        outputPath: AbsolutePath
    ) async throws {
        let (graph, _, _, _) = try await manifestGraphLoader.load(path: path)

        let filePath = outputPath.appending(component: "graph.\(format.rawValue)")
        if FileHandler.shared.exists(filePath) {
            logger.notice("Deleting existing graph at \(filePath.pathString)")
            try FileHandler.shared.delete(filePath)
        }

        let filteredTargetsAndDependencies = graph.filter(
            skipTestTargets: skipTestTargets,
            skipExternalDependencies: skipExternalDependencies,
            platformToFilter: platformToFilter,
            targetsToFilter: targetsToFilter
        )

        switch format {
        case .json:
            let outputGraph = ProjectAutomation.Graph.from(graph: graph, targetsAndDependencies: filteredTargetsAndDependencies)
            try outputGraph.export(to: filePath)
        }

        logger.notice("Graph exported to \(filePath.pathString)", metadata: .success)
    }
}

enum GraphServiceError: FatalError {
    case jsonNotValidForVisualExport
    case encodingError(String)
    case graphVizNotInstalled

    var description: String {
        switch self {
        case .jsonNotValidForVisualExport:
            return "json format is not valid for visual export"
        case let .encodingError(format):
            return "failed to encode graph to \(format)"
        case .graphVizNotInstalled:
            return "To create visual graph representation, geko needs installed graphviz."
        }
    }

    var type: ErrorType {
        return .abort
    }
}

extension ProjectAutomation.Graph {
    fileprivate static func from(
        graph: GekoGraph.Graph,
        targetsAndDependencies: [GraphTarget: Set<GraphDependency>]
    ) -> ProjectAutomation.Graph {
        // generate targets projects only
        let projects =
            targetsAndDependencies
            .map(\.key.project)
            .reduce(into: [String: ProjectAutomation.Project]()) {
                $0[$1.path.pathString] = ProjectAutomation.Project.from($1)
            }

        return ProjectAutomation.Graph(name: graph.name, path: graph.path.pathString, projects: projects)
    }

    fileprivate func export(to filePath: AbsolutePath) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let jsonData = try encoder.encode(self)
        let jsonString = String(data: jsonData, encoding: .utf8)
        guard let jsonString else {
            throw GraphServiceError.encodingError(GraphFormat.json.rawValue)
        }

        try FileHandler.shared.write(jsonString, path: filePath, atomically: true)
    }
}

extension ProjectAutomation.Project {
    fileprivate static func from(_ project: ProjectDescription.Project) -> ProjectAutomation.Project {
        let schemes = project.schemes.reduce(into: [ProjectAutomation.Scheme]()) { $0.append(ProjectAutomation.Scheme.from($1)) }
        let targets = project.targets.reduce(into: [ProjectAutomation.Target]()) { $0.append(ProjectAutomation.Target.from($1)) }

        return ProjectAutomation.Project(
            name: project.name,
            path: project.path.pathString,
            isExternal: project.isExternal,
            targets: targets,
            schemes: schemes
        )
    }
}

extension ProjectAutomation.Target {
    fileprivate static func from(_ target: ProjectDescription.Target) -> ProjectAutomation.Target {
        let dependencies = target.dependencies.map { Self.from($0) }
        return ProjectAutomation.Target(
            name: target.name,
            product: target.product.rawValue,
            sources: target.sources.flatMap { $0.paths.map(\.pathString) },
            resources: target.resources.map(\.path.pathString),
            dependencies: dependencies
        )
    }

    private static func from(_ dependency: ProjectDescription.TargetDependency) -> ProjectAutomation.TargetDependency {
        switch dependency {
        case let .target(name, status, _):
            let linkingStatus: ProjectAutomation.LinkingStatus = status == .optional ? .optional : .required
            return .target(name: name, status: linkingStatus)
        case let .local(name, status, _):
            let linkingStatus: ProjectAutomation.LinkingStatus = status == .optional ? .optional : .required
            return .local(name: name, status: linkingStatus)
        case let .external(name, _):
            return .external(name: name)
        case let .project(target, path, status, _):
            let linkingStatus: ProjectAutomation.LinkingStatus = status == .optional ? .optional : .required
            return .project(target: target, path: path.pathString, status: linkingStatus)
        case let .framework(path, status, _):
            let frameworkStatus: ProjectAutomation.LinkingStatus
            switch status {
            case .optional:
                frameworkStatus = .optional
            case .required:
                frameworkStatus = .required
            case .none:
                frameworkStatus = .none
            }
            return .framework(path: path.pathString, status: frameworkStatus)
        case let .xcframework(path, status, _):
            let frameworkStatus: ProjectAutomation.LinkingStatus
            switch status {
            case .optional:
                frameworkStatus = .optional
            case .required:
                frameworkStatus = .required
            case .none:
                frameworkStatus = .none
            }
            return .xcframework(path: path.pathString, status: frameworkStatus)
        case let .library(path, publicHeaders, swiftModuleMap, _):
            return .library(
                path: path.pathString,
                publicHeaders: publicHeaders.pathString,
                swiftModuleMap: swiftModuleMap?.pathString
            )
        case let .sdk(name, _, status, _):
            let projectAutomationStatus: ProjectAutomation.LinkingStatus
            switch status {
            case .optional:
                projectAutomationStatus = .optional
            case .required:
                projectAutomationStatus = .required
            case .none:
                projectAutomationStatus = .none
            }
            return .sdk(name: name, status: projectAutomationStatus)
        case let .bundle(path, _):
            return .bundle(path: path.pathString)
        case .xctest:
            return .xctest
        }
    }
}

extension ProjectAutomation.Scheme {
    fileprivate static func from(_ scheme: ProjectDescription.Scheme) -> ProjectAutomation.Scheme {
        var testTargets = [String]()
        if let testAction = scheme.testAction {
            for testTarget in testAction.targets {
                testTargets.append(testTarget.target.name)
            }
        }

        return ProjectAutomation.Scheme(name: scheme.name, testActionTargets: testTargets)
    }
}
