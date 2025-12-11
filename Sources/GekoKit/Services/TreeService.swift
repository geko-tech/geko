import Foundation
import ProjectDescription
import GekoDependencies
import GekoGraph
import GekoLoader
import GekoSupport
import struct ProjectDescription.AbsolutePath
import GekoCore

private struct TreeDependency: Encodable {
    let version: String?
    let isExternal: Bool
    var dependencies: Set<String>
}

enum TreeServiceError: FatalError {
    case missingDependency(String)

    var type: GekoSupport.ErrorType {.abort }

    var description: String {
        switch self {
        case let .missingDependency(dep):
            return "\(dep) is not in the tree"
        }
    }
}

final class TreeService {
    private let dependenciesGraphController: DependenciesGraphControlling
    private let graphLoader: ManifestGraphLoading

    init(
        dependenciesGraphController: DependenciesGraphControlling = DependenciesGraphController(),
        graphLoader: ManifestGraphLoading = ManifestGraphLoader.init(
            manifestLoader: ManifestLoaderFactory().createManifestLoader(),
            workspaceMapper: SequentialWorkspaceMapper(mappers: []),
            graphMapper: SequentialGraphMapper([])
        )
    ) {
        self.dependenciesGraphController = dependenciesGraphController
        self.graphLoader = graphLoader
    }

    func run(
        targets: consuming [String],
        external: Bool,
        usage: Bool,
        minified: Bool,
        outputFile: String?
    ) async throws {
        let externalGraph = try dependenciesGraphController.load(at: .current)
        var localGraph: Graph?
        if !external {
            (localGraph, _, _, _) = try await graphLoader.load(path: .current)
        }

        var tree = buildTree(externalGraph: externalGraph, localGraph: localGraph)
        if usage {
            tree = flipTree(tree)
        }
        if minified {
            minimalSpanningTree(&tree)
        }

        if let outputFile {
            try dumpJson(tree: tree, output: outputFile, targets: targets)
        } else {
            try printTree(tree, targets: targets)
        }
    }

    private func buildTree(
        externalGraph: consuming GekoGraph.DependenciesGraph,
        localGraph: consuming Graph?
    ) -> [String: TreeDependency] {
        var result: [String: TreeDependency] = [:]

        for (name, dep) in externalGraph.tree {
            result[name] = .init(
                version: dep.version,
                isExternal: true,
                dependencies: Set(dep.dependencies)
            )
        }

        guard let localGraph else { return result }

        var frameworkToDepName: [AbsolutePath: String] = [:]
        for (depName, targetDeps) in localGraph.externalDependenciesGraph.externalDependencies {
            for targetDep in targetDeps {
                switch targetDep {
                case let .xcframework(path, _, _), let .framework(path, _, _), let .bundle(path, _):
                    frameworkToDepName[path] = depName
                case .library, .local, .project, .sdk, .target, .xctest, .external:
                    continue
                }
            }
        }

        for target in localGraph.projects.values.lazy.flatMap(\.targets) {
            var dependencies: Set<String> = []

            for dep in target.dependencies {
                switch dep {
                case let .target(name, _, _):
                    dependencies.insert(name)
                case let .local(name, _, _):
                    dependencies.insert(name)
                case let .project(target, _, _, _):
                    dependencies.insert(target.name)
                case .framework(path: let path, _, _):
                    if let depName = frameworkToDepName[path] {
                        dependencies.insert(depName)
                    }
                case .xcframework(path: let path, _, _):
                    if let depName = frameworkToDepName[path] {
                        dependencies.insert(depName)
                    }
                case .bundle(path: let path, _):
                    if let depName = frameworkToDepName[path] {
                        dependencies.insert(depName)
                    }
                case .external(name: let name, _):
                    dependencies.insert(name)
                case .library, .sdk, .xctest:
                    continue
                }
            }

            result[target.name] = .init(
                version: nil,
                isExternal: false,
                dependencies: dependencies
            )
        }

        return result
    }

    private func flipTree(
        _ tree: [String: TreeDependency]
    ) -> [String: TreeDependency] {
        var result: [String: TreeDependency] = tree.mapValues {
            .init(
                version: $0.version,
                isExternal: $0.isExternal,
                dependencies: []
            )
        }

        func defaultNode(_ node: String) -> TreeDependency {
            if let dep = tree[node] {
                return .init(
                    version: dep.version,
                    isExternal: dep.isExternal,
                    dependencies: []
                )
            }

            return .init(version: nil, isExternal: false, dependencies: [])
        }

        for (name, dep) in tree {
            for depDep in dep.dependencies {
                result[depDep, default: defaultNode(depDep)]
                    .dependencies
                    .insert(name)
            }
        }

        return result
    }

    private func minimalSpanningTree(_ tree: inout [String: TreeDependency]) {
        var flatDependencies: [String: Set<String>] = [:]

        func dfs(_ node: String) {
            guard flatDependencies[node] == nil else { return }

            guard let deps = tree[node]?.dependencies, !deps.isEmpty else {
                flatDependencies[node] = []
                return
            }

            flatDependencies[node, default: []].formUnion(deps)
            for child in deps {
                if flatDependencies[child] == nil {
                    dfs(child)
                }

                flatDependencies[node, default: []].formUnion(flatDependencies[child] ?? [])
            }
        }

        for start in tree.keys {
            dfs(start)
        }

        for node in tree.keys {
            var currentTransitiveDeps: Set<String> = []

            for child in tree[node]?.dependencies ?? [] {
                currentTransitiveDeps.formUnion(flatDependencies[child] ?? [])
            }

            for child in tree[node]?.dependencies ?? [] {
                if currentTransitiveDeps.contains(child) {
                    tree[node]!.dependencies.remove(child)
                }
            }
        }
    }

    private func printTree(
        _ tree: borrowing [String: TreeDependency],
        targets: [String]
    ) throws {
        var seen: Set<String> = []

        var prefix = ""
        func printNode(_ node: String) {
            print(node, terminator: "")
            if let version = tree[node]?.version, !version.isEmpty {
                print(" (\(version))", terminator: "")
            }
            print()

            seen.insert(node)

            guard let deps = tree[node]?.dependencies else {
                return
            }

            for (idx, child) in deps.sorted().enumerated() {
                if idx == deps.count - 1 {
                    print(prefix + "└─", terminator: "")
                    prefix += "  "
                } else {
                    print(prefix + "├─", terminator: "")
                    prefix += "│ "
                }

                printNode(child)
                prefix.removeLast(2)
            }
        }

        if !targets.isEmpty  {
            for target in targets {
                guard tree[target] != nil else {
                    throw TreeServiceError.missingDependency(target)
                }

                printNode(target)
                print()
            }
        } else {
            let toposort = topologicalSort(tree: tree)
            for i in stride(from: toposort.count - 1, to: 0, by: -1) {
                guard !seen.contains(toposort[i]) else { continue }

                printNode(toposort[i])
                print()
            }
        }
    }

    private func topologicalSort(tree: borrowing [String: TreeDependency]) -> [String] {
        var result: [String] = []
        result.reserveCapacity(tree.count)

        var marks: Set<String> = []

        func visit(_ node: String) {
            if marks.contains(node) {
                return
            }

            for child in tree[node]?.dependencies ?? [] {
                visit(child)
            }

            marks.insert(node)
            result.append(node)
        }

        for node in tree.keys {
            guard !marks.contains(node) else { continue }
            visit(node)
        }

        return result
    }

    private func dumpJson(
        tree: consuming [String: TreeDependency],
        output: String,
        targets: [String]
    ) throws {
        var tree = consume tree

        let path: AbsolutePath
        if let relativePath = try? RelativePath(validating: output) {
            path = AbsolutePath.current.appending(relativePath)
        } else {
            path = try AbsolutePath(validatingAbsolutePath: output)
        }

        if !targets.isEmpty {
            var visited: Set<String> = []
            var queue = Set(targets)

            while !queue.isEmpty {
                let node = queue.removeFirst()
                visited.insert(node)

                guard let deps = tree[node] else {
                    throw TreeServiceError.missingDependency(node)
                }

                queue.formUnion(deps.dependencies.subtracting(visited))
            }

            for key in tree.keys {
                if !visited.contains(key) {
                    tree[key] = nil
                }
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(tree)

        try data.write(to: path.url)
    }
}
