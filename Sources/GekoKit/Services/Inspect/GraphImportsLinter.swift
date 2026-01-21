import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

enum InspectType {
    case redundant
    case implicit
}

protocol GraphImportsLinting {
    func lint(
        graphTraverser: GraphTraverser,
        config: GraphImportsLinterConfig,
        sideEffects: [SideEffectDescriptor],
        inspectType: InspectType,
        severity: LintingIssue.Severity,
        inspectMode: InspectMode,
        output: AbsolutePath?
    ) async throws -> [LintingIssue]
}

struct GraphImportsLinterConfig: Codable {
    var exclude: [String: Set<String>]

    static let `default` = GraphImportsLinterConfig(
        exclude: [:]
    )
}

final class GraphImportsLinter: GraphImportsLinting {
    // MARK: - Attributes

    private let targetScanner: TargetImportsScanning
    private let logDirectoryProvider: LogDirectoriesProviding
    private let fileHandler: FileHandling
    private let environment: Environmenting
    private let system: Systeming
    private let ciChecker: CIChecking

    // MARK: - Initialization

    init(
        targetScanner: TargetImportsScanning = TargetImportsScanner(),
        logDirectoryProvider: LogDirectoriesProviding = LogDirectoriesProvider(),
        fileHandler: FileHandling = FileHandler.shared,
        environment: Environmenting = Environment.shared,
        system: Systeming = System.shared,
        ciChecker: CIChecking = CIChecker()
    ) {
        self.targetScanner = targetScanner
        self.logDirectoryProvider = logDirectoryProvider
        self.fileHandler = fileHandler
        self.environment = environment
        self.system = system
        self.ciChecker = ciChecker
    }

    // MARK: - GraphImportsLinting

    func lint(
        graphTraverser: GekoCore.GraphTraverser,
        config: GraphImportsLinterConfig,
        sideEffects: [SideEffectDescriptor],
        inspectType: InspectType,
        severity: LintingIssue.Severity,
        inspectMode: InspectMode,
        output: AbsolutePath?
    ) async throws -> [LintingIssue] {
        let lintedTargets = try await targetImportsMap(
            graphTraverser: graphTraverser,
            config: config,
            sideEffects: sideEffects,
            inspectType: inspectType,
            inspectMode: inspectMode
        )
        if let output {
            try saveOutput(
                lintedTargets: lintedTargets,
                outputPath: output
            )
        }

        return lintedTargets.compactMap { target, implicitDependencies in
            return LintingIssue(
                reason: " - \(target.productName) \(inspectType == .implicit ? "implicitly" : "redundantly") depends on: \(implicitDependencies.joined(separator: ", "))",
                severity: severity
            )
        }
    }

    private func targetImportsMap(
        graphTraverser: GraphTraverser,
        config: GraphImportsLinterConfig,
        sideEffects: [SideEffectDescriptor],
        inspectType: InspectType,
        inspectMode: InspectMode
    ) async throws -> [Target: Set<String>] {
        var observedTargetImports: [Target: Set<String>] = [:]
        let excludedImports = config.exclude
        let allDependencies = try findAllTransitiveDependencies(graphTraverser: graphTraverser)
        let allDependenciesNames = Set(allDependencies.keys.map { $0.nameWithoutExtension })
        let allInternalGraphDependencies = allDependencies.reduce(into: [GraphTarget: Set<GraphDependency>]()) { acc, dependency in
            switch dependency.key {
            case let .target(name, path, _):
                guard
                    let target = graphTraverser.target(path: path, name: name),
                    !target.project.isExternal
                else { return }
                acc[target] = dependency.value
            default:
                break
            }
        }
        let targetsToInspect: [GraphTarget: Set<GraphDependency>]
        switch inspectMode {
        case .full:
            targetsToInspect = allInternalGraphDependencies
        case .diff:
            let changedFiles = try changedFiles()
            let changedLocalTargets = try changedLocalTargets(
                graphTraverser: graphTraverser,
                changedFiles: changedFiles
            ).reduce(into: [GraphTarget: Set<GraphDependency>]()) { acc, target in
                acc[target] = allInternalGraphDependencies[target] ?? []
            }
            targetsToInspect = changedLocalTargets
        }

        for (target, dependencies) in targetsToInspect {
            let sourceDependencies = Set(try await targetScanner.imports(for: target.target, sideEffects: sideEffects))

            var observedImports: Set<String>
            switch inspectType {
            case .redundant:
                let directDependencies = Set(graphTraverser.directTargetDependencies(
                    path: target.project.path,
                    name: target.target.name
                ).filter {
                    switch $0.graphTarget.target.product {
                    case .staticLibrary, .staticFramework, .dynamicLibrary, .framework:
                        return true
                    default:
                        return false
                    }
                }.map { $0.target.productName })
                observedImports = directDependencies.subtracting(sourceDependencies)
            case .implicit:
                let explicitTargetDependencies = Set(dependencies.map { $0.nameWithoutExtension })
                observedImports = sourceDependencies
                    .subtracting(explicitTargetDependencies)
                    .intersection(allDependenciesNames)
            }
            observedImports.subtract(excludedImports[target.target.productName] ?? [])

            if !observedImports.isEmpty {
                observedTargetImports[target.target] = observedImports
            }
        }
        return observedTargetImports
    }

    private func findAllTransitiveDependencies(
        graphTraverser: GraphTraverser
    ) throws -> [GraphDependency: Set<GraphDependency>] {
        let dependencies = graphTraverser.dependencies
        var visitedDependencies = [GraphDependency: Set<GraphDependency>]()

        for dependency in dependencies.keys {
            try transitiveDependencies(
                for: dependency,
                visitedDependencies: &visitedDependencies,
                graphTraverser: graphTraverser
            )
        }

        return visitedDependencies
    }

    private func transitiveDependencies(
        for dependency: GraphDependency,
        visitedDependencies: inout [GraphDependency: Set<GraphDependency>],
        graphTraverser: GraphTraverser
    ) throws {
        if let _ = visitedDependencies[dependency] { return }

        let directDeps = graphTraverser.dependencies[dependency] ?? []

        var transitiveDeps: Set<GraphDependency> = []
        for child in directDeps {
            // We need to filter out dependencies that might be AppHost and not collect their transitive dependencies
            if case let .target(name, path, _) = child,
               let target = graphTraverser.target(path: path, name: name),
               target.target.product.canHostTests() {
                continue
            }
            try transitiveDependencies(
                for: child,
                visitedDependencies: &visitedDependencies,
                graphTraverser: graphTraverser
            )
            transitiveDeps.formUnion(visitedDependencies[child] ?? [])
        }

        transitiveDeps.formUnion(directDeps)
        visitedDependencies[dependency] = transitiveDeps
    }

    private func saveOutput(
        lintedTargets: [Target: Set<String>],
        outputPath: AbsolutePath
    ) throws {
        if fileHandler.exists(outputPath) {
            try fileHandler.delete(outputPath)
        }

        let output = lintedTargets.reduce(into: [String: Set<String>]()) { acc, linted in
            acc[linted.key.productName] = linted.value
        }
        let jsonData = try JSONEncoder().encode(output)
        guard let content = String(data: jsonData, encoding: .utf8) else {
            throw FileHandlerError.invalidTextEncoding(outputPath)
        }

        try fileHandler.createFolder(outputPath.parentDirectory)
        try fileHandler.write(
            content,
            path: outputPath,
            atomically: true
        )
    }
}

// MARK: - Source & Diff calculation

private extension GraphImportsLinter {
    private var sourceRef: String {
        environment.inspectSourceRef ?? "HEAD"
    }

    private var targetRef: String {
        guard let ref = environment.inspectTargetRef else {
            fatalError("Environment variable \(Constants.EnvironmentVariables.inspectTargetRef) should be set")
        }
        return ref
    }

    private func changedFiles() throws -> Set<String> {
        let diff: String
        if ciChecker.isCI() {
            diff = try system.capture(["git", "diff", "\(targetRef)...\(sourceRef)", "--name-only"]).chomp()
        } else {
            diff = try system.capture(["git", "diff", "--name-only"]).chomp()
        }

        return Set(diff.components(separatedBy: "\n"))
    }

    private func changedLocalTargets(
        graphTraverser: GraphTraverser,
        changedFiles: borrowing Set<String>
    ) throws -> Set<GraphTarget> {
        var result = Set<GraphTarget>()

        let rootPath = graphTraverser.workspace.path
        let changedFilesAbsolutePaths = try changedFiles.map {
            let relativePath = try RelativePath(validating: $0)
            return rootPath.appending(relativePath)
        }

        for project in graphTraverser.projects.values {
            let projectManifest: String =
                if let podspecPath = project.podspecPath {
                    podspecPath.relative(to: rootPath).pathString
                } else {
                    project.path
                        .relative(to: rootPath)
                        .appending(component: "Project.swift")
                        .pathString
                }
            if changedFiles.contains(projectManifest) {
                for target in project.targets {
                    if let changedTarget = graphTraverser.target(path: project.path, name: target.name){
                        result.insert(changedTarget)
                    }
                }
                continue
            }

            targetLoop: for target in project.targets {
                for sourceFiles in target.sources {
                    for source in sourceFiles.paths {
                        let relativePath = source.relative(to: rootPath).pathString
                        if changedFiles.contains(relativePath) {
                            if let changedTarget = graphTraverser.target(path: project.path, name: target.name){
                                result.insert(changedTarget)
                            }

                            continue targetLoop
                        }
                    }
                }

                for buildableFolder in target.buildableFolders {
                    for changedFile in changedFilesAbsolutePaths {
                        if buildableFolder.path.isAncestor(of: changedFile)
                            && !buildableFolder.exceptions.contains(changedFile)
                        {
                            if let changedTarget = graphTraverser.target(path: project.path, name: target.name){
                                result.insert(changedTarget)
                            }

                            continue targetLoop
                        }
                    }
                }
            }
        }

        return result
    }
}
