import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

// MARK: - CircularDependencyLinting

public protocol CircularDependencyLinting {
    func lintWorkspace(workspace: Workspace, projects: [Project], externalDependencies: GekoGraph.DependenciesGraph) throws
}

// MARK: - CircularDependencyLinter

enum CircularDependencyLinterError: FatalError {
    case duplicateTargetName(
        name: String, firstProject: AbsolutePath, secondProject: AbsolutePath
    )

    var type: ErrorType { .abort }

    var description: String {
        switch self {
        case let .duplicateTargetName(name, firstProject, secondProject):
            if firstProject == secondProject {
                return "Found two targets with the same name '\(name)' at \(firstProject)"
            }

            return """
                Found two targets with the same name '\(name)' at
                \(firstProject)
                \(secondProject)
                """
        }
    }
}

public class CircularDependencyLinter: CircularDependencyLinting {
    private struct Node {
        var name: String
        var path: AbsolutePath
        var dependencies: [String] = []
        var indegree: Int
        var projectIdx: Int
        var targetIdx: Int

        mutating func update(
            name: consuming String,
            path: consuming AbsolutePath,
            projectIdx: Int,
            targetIdx: Int
        ) {
            self.name = name
            self.path = path
            self.projectIdx = projectIdx
            self.targetIdx = targetIdx
        }

        static let `default`: Node = .init(
            name: "",
            path: ".",
            indegree: 0,
            projectIdx: -1,
            targetIdx: -1
        )
    }

    public init() {}

    public func lintWorkspace(workspace: Workspace, projects: [Project], externalDependencies: GekoGraph.DependenciesGraph) throws {
        var (map, queue) = try buildIndegreeMap(
            projects: projects,
            externalDependencies: externalDependencies
        )

        var newQueue: [String] = []

        // Following code uses Kahn topological sorting.
        // When algorithm is done, map should include
        // nodes with indegree count > 0 if there is a cycle.
        while !queue.isEmpty {
            for node in queue {
                for dep in map[node]!.dependencies {
                    map[dep]!.indegree -= 1

                    if map[dep]!.indegree == 0 {
                        newQueue.append(dep)
                    }
                }
            }

            swap(&queue, &newQueue)
            newQueue.removeAll(keepingCapacity: true)
        }

        for key in map.keys {
            if map[key]!.indegree > 0 {
                let cycle = findCycle(start: key, map: &map)
                if !cycle.isEmpty {
                    throw GraphLoadingError.circularDependency(
                        cycle.map { GraphCircularDetectorNode(path: map[$0]!.path, name: $0) }
                    )
                }
            }
        }
    }

    // MARK: - Private

    private func buildIndegreeMap(
        projects: [Project],
        externalDependencies: GekoGraph.DependenciesGraph
    ) throws -> ([String: Node], [String]) {
        var resultMap: [String: Node] = [:]

        for projectIdx in 0 ..< projects.count {
            for targetIdx in 0 ..< projects[projectIdx].targets.count {
                let path = projects[projectIdx].path
                let targetName = projects[projectIdx].targets[targetIdx].name

                if resultMap[targetName] == nil {
                    resultMap[targetName] = .init(
                        name: targetName,
                        path: path,
                        indegree: 0,
                        projectIdx: projectIdx,
                        targetIdx: targetIdx
                    )
                } else {
                    let otherProjectIdx = resultMap[targetName]!.projectIdx
                    let otherTargetIdx = resultMap[targetName]!.targetIdx

                    if otherProjectIdx >= 0 || otherTargetIdx >= 0 {
                        guard otherProjectIdx == projectIdx, otherTargetIdx == targetIdx else {
                            // fatalError("duplicate target names")
                            throw CircularDependencyLinterError.duplicateTargetName(
                                name: targetName,
                                firstProject: path,
                                secondProject: resultMap[targetName]!.path
                            )
                        }
                    }

                    resultMap[targetName]!.update(name: targetName, path: path, projectIdx: projectIdx, targetIdx: targetIdx)
                }

                for dependency in projects[projectIdx].targets[targetIdx].dependencies {
                    switch dependency {
                    case .target(name: let name, status: _, condition: _),
                        .local(name: let name, status: _, condition: _),
                        .project(target: let name, path: _, status: _, condition: _):
                        resultMap[name, default: .default].indegree += 1
                        resultMap[targetName]!.dependencies.append(name)

                    case .external(name: let name, condition: _):
                        for dep in (externalDependencies.externalDependencies[name] ?? []) {
                            switch dep {
                            case .local(name: let name, status: _, condition: _),
                                .project(target: let name, path: _, status: _, condition: _):
                                resultMap[name, default: .default].indegree += 1
                                resultMap[targetName]!.dependencies.append(name)
                            default:
                                break
                            }
                        }

                    case .framework, .library, .sdk, .xcframework, .bundle, .xctest:
                        break
                    }
                }
            }
        }

        var rootNodes: [String] = []

        for key in resultMap.keys {
            if resultMap[key]!.indegree == 0 {
                rootNodes.append(key)
            }
        }

        return (resultMap, rootNodes)
    }

    private func findCycle(start: String, map: inout [String: Node]) -> [String] {
        var path: [String] = [start]
        // var visited: Set<String> = [start]

        outer: while !path.isEmpty {
            let node = path[path.count - 1]
            // visited.insert(node)

            for dep in map[node]!.dependencies {
                if map[dep]!.indegree > 0 {
                    if path.contains(dep) {
                        path.append(dep)
                        return path
                    }

                    path.append(dep)

                    continue outer
                }
            }

            path.removeLast()
            // visited.remove(node)
            // this node does not form cycle
            map[node]!.indegree -= 1
        }

        return path
    }
}
