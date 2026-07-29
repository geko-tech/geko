import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

enum ModuleMapMapperError: FatalError {
    case invalidTargetDependency(sourceProject: AbsolutePath, sourceTarget: String, dependentTarget: String)
    case invalidProjectTargetDependency(
        sourceProject: AbsolutePath,
        sourceTarget: String,
        dependentProject: AbsolutePath,
        dependentTarget: String
    )

    /// Error type.
    var type: ErrorType {
        switch self {
        case .invalidTargetDependency, .invalidProjectTargetDependency: return .abort
        }
    }

    /// Error description.
    var description: String {
        switch self {
        case let .invalidTargetDependency(sourceProject, sourceTarget, dependentTarget):
            return """
            Target '\(sourceTarget)' of the project at path '\(sourceProject.pathString)' \
            depends on a target '\(dependentTarget)' that can't be found. \
            Please make sure your project configuration is correct.
            """
        case let .invalidProjectTargetDependency(sourceProject, sourceTarget, dependentProject, dependentTarget):
            return """
            Target '\(sourceTarget)' of the project at path '\(sourceProject.pathString)' \
            depends on a target '\(dependentTarget)' of the project at path '\(
                dependentProject
                    .pathString
            )' that can't be found. \
            Please make sure your project configuration is correct.
            """
        }
    }
}

/// Mapper that maps the `MODULE_MAP` build setting to the `-fmodule-map-file` compiler flags.
/// It is required to avoid embedding the module map into the frameworks during cache operations, which would make the framework
/// not portable, as
/// the modulemap could contain absolute paths.
public final class ModuleMapMapper: GraphMapping {
    private static let modulemapFileSetting = "MODULEMAP_FILE"
    private static let otherCFlagsSetting = "OTHER_CFLAGS"
    private static let otherSwiftFlagsSetting = "OTHER_SWIFT_FLAGS"
    private static let headerSearchPaths = "HEADER_SEARCH_PATHS"

    private struct TargetID: Hashable {
        let projectPath: AbsolutePath
        let targetName: String
    }
    
    private struct DependencyMetadata: Hashable {
        let moduleMapPath: AbsolutePath?
        let headerSearchPaths: [String]
    }

    private struct DependenciesModuleMapsFrame {
        let target: GraphTarget
        var nextDependencyIndex: Int
        var dependenciesMetadata: Set<DependencyMetadata>
    }

    private struct ResolvedDependency {
        let project: Project
        let target: GraphTarget
    }

    public init() {}

    // swiftlint:disable function_body_length
    public func map(
        graph: inout GekoGraph.Graph,
        sideTable: inout GekoGraph.GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        var targetToDependenciesMetadata: [TargetID: Set<DependencyMetadata>] = [:]
        let graphTraverser = GraphTraverser(graph: graph)
        for target in graphTraverser.allTargets().filter({ $0.project.projectType != .cocoapods }) {
            try dependenciesModuleMaps(
                graph: graph,
                graphTraverser: graphTraverser,
                target: target,
                targetToDependenciesMetadata: &targetToDependenciesMetadata
            )
        }

        graph.projects = Dictionary(uniqueKeysWithValues: graph.projects.map { projectPath, project in
            var project = project
            guard project.projectType != .cocoapods else { return (projectPath, project) }
            project.targets = project.targets.map { target in
                var target = target
                let targetID = TargetID(projectPath: project.path, targetName: target.name)
                var mappedSettingsDictionary = target.settings?.base ?? [:]
                let hasModuleMap = mappedSettingsDictionary[Self.modulemapFileSetting] != nil
                guard hasModuleMap || !(targetToDependenciesMetadata[targetID]?.isEmpty ?? true) else { return target }

                // Apply moduleMap logic only for spm dependencies
                if hasModuleMap, project.projectType == .spm {
                    mappedSettingsDictionary[Self.modulemapFileSetting] = nil
                }

                if let updatedOtherSwiftFlags = updatedOtherSwiftFlags(
                    targetID: targetID,
                    oldOtherSwiftFlags: mappedSettingsDictionary[Self.otherSwiftFlagsSetting],
                    targetToDependenciesMetadata: targetToDependenciesMetadata
                ) {
                    mappedSettingsDictionary[Self.otherSwiftFlagsSetting] = updatedOtherSwiftFlags
                }

                if let updatedOtherCFlags = updatedOtherCFlags(
                    targetID: targetID,
                    oldOtherCFlags: mappedSettingsDictionary[Self.otherCFlagsSetting],
                    targetToDependenciesMetadata: targetToDependenciesMetadata
                ) {
                    mappedSettingsDictionary[Self.otherCFlagsSetting] = updatedOtherCFlags
                }

                if let updatedHeaderSearchPaths = updatedHeaderSearchPaths(
                    targetID: targetID,
                    oldHeaderSearchPaths: mappedSettingsDictionary[Self.headerSearchPaths],
                    targetToDependenciesMetadata: targetToDependenciesMetadata
                ) {
                    mappedSettingsDictionary[Self.headerSearchPaths] = updatedHeaderSearchPaths
                }

                let targetSettings = target.settings ?? Settings(
                    base: [:],
                    configurations: [:],
                    defaultSettings: project.settings.defaultSettings
                )

                target.settings = targetSettings.with(base: mappedSettingsDictionary)
                graph.targets[project.path]?[target.name] = target

                return target
            }
            return (projectPath, project)
        })

        return []
    }// swiftlint:enable function_body_length

    /// Calculates the set of module maps to be linked to a given target and populates the `targetToDependenciesMetadata` dictionary.
    /// Each target must link the module map of its direct and indirect dependencies.
    /// The `targetToDependenciesMetadata` is also used as cache to avoid recomputing the set for already computed targets.
    private func dependenciesModuleMaps( // swiftlint:disable:this function_body_length
        graph: Graph,
        graphTraverser: GraphTraverser,
        target: GraphTarget,
        targetToDependenciesMetadata: inout [TargetID: Set<DependencyMetadata>]
    ) throws {
        let rootTargetID = targetID(for: target)
        if targetToDependenciesMetadata[rootTargetID] != nil {
            // already computed
            return
        }

        var activeTargetIDs = Set([rootTargetID])
        var stack = [
            DependenciesModuleMapsFrame(
                target: target,
                nextDependencyIndex: 0,
                dependenciesMetadata: []
            ),
        ]

        while !stack.isEmpty {
            let frameIndex = stack.count - 1
            let frame = stack[frameIndex]

            if frame.nextDependencyIndex < frame.target.target.dependencies.count {
                let dependency = frame.target.target.dependencies[frame.nextDependencyIndex]

                guard
                    let resolvedDependency = try resolve(
                        dependency: dependency,
                        from: frame.target,
                        graph: graph,
                        graphTraverser: graphTraverser
                    )
                else {
                    stack[frameIndex].nextDependencyIndex += 1
                    continue
                }

                let dependencyTargetID = targetID(for: resolvedDependency.target)
                if let indirectDependencyMetadata = targetToDependenciesMetadata[dependencyTargetID] {
                    stack[frameIndex].nextDependencyIndex += 1
                    stack[frameIndex].dependenciesMetadata.formUnion(indirectDependencyMetadata)
                    stack[frameIndex].dependenciesMetadata.insert(
                        try dependencyMetadata(for: resolvedDependency)
                    )
                    continue
                }

                if activeTargetIDs.contains(dependencyTargetID) {
                    throw GraphError.unexpectedCycle
                }

                activeTargetIDs.insert(dependencyTargetID)
                stack.append(
                    DependenciesModuleMapsFrame(
                        target: resolvedDependency.target,
                        nextDependencyIndex: 0,
                        dependenciesMetadata: []
                    )
                )
            } else {
                let completedFrame = stack.removeLast()
                let completedTargetID = targetID(for: completedFrame.target)
                targetToDependenciesMetadata[completedTargetID] = completedFrame.dependenciesMetadata
                activeTargetIDs.remove(completedTargetID)
            }
        }
    }

    private func targetID(for target: GraphTarget) -> TargetID {
        TargetID(projectPath: target.path, targetName: target.target.name)
    }

    private func resolve(
        dependency: TargetDependency,
        from target: GraphTarget,
        graph: Graph,
        graphTraverser: GraphTraverser
    ) throws -> ResolvedDependency? {
        let dependentProject: Project
        let dependentTarget: GraphTarget

        switch dependency {
        case let .target(name, _, _):
            guard let resolvedTarget = graphTraverser.target(path: target.path, name: name) else {
                throw ModuleMapMapperError.invalidTargetDependency(
                    sourceProject: target.project.path,
                    sourceTarget: target.target.name,
                    dependentTarget: name
                )
            }
            dependentProject = target.project
            dependentTarget = resolvedTarget

        case let .project(name, path, _, _):
            guard
                let resolvedProject = graph.projects[path],
                let resolvedTarget = graphTraverser.target(path: path, name: name)
            else {
                throw ModuleMapMapperError.invalidProjectTargetDependency(
                    sourceProject: target.project.path,
                    sourceTarget: target.target.name,
                    dependentProject: path,
                    dependentTarget: name
                )
            }
            dependentProject = resolvedProject
            dependentTarget = resolvedTarget

        case .framework, .xcframework, .library, .sdk, .xctest, .bundle, .external, .local:
            return nil
        }

        guard dependentTarget.project.projectType != .cocoapods else {
            return nil
        }

        return ResolvedDependency(project: dependentProject, target: dependentTarget)
    }

    private func dependencyMetadata(for dependency: ResolvedDependency) throws -> DependencyMetadata {
        let dependencyModuleMapPath: AbsolutePath?
        let pathString = dependency.project.path.pathString

        if case let .string(dependencyModuleMap) = dependency.target.target.settings?.base[Self.modulemapFileSetting],
           dependency.target.project.projectType == .spm
        {
            dependencyModuleMapPath = try AbsolutePath(
                validating: dependencyModuleMap
                    .replacingOccurrences(of: "$(PROJECT_DIR)", with: pathString)
                    .replacingOccurrences(of: "$(SRCROOT)", with: pathString)
                    .replacingOccurrences(of: "$(SOURCE_ROOT)", with: pathString)
            )
        } else {
            dependencyModuleMapPath = nil
        }

        let headerSearchPaths: [String]
        switch dependency.target.target.settings?.base[Self.headerSearchPaths] ?? .array([]) {
        case let .array(values):
            headerSearchPaths = values
        case let .string(value):
            headerSearchPaths = [value]
        }

        return DependencyMetadata(
            moduleMapPath: dependencyModuleMapPath,
            headerSearchPaths: headerSearchPaths.map {
                (
                    try? AbsolutePath(
                        validating: $0
                            .replacingOccurrences(of: "$(PROJECT_DIR)", with: pathString)
                            .replacingOccurrences(of: "$(SRCROOT)", with: pathString)
                            .replacingOccurrences(of: "$(SOURCE_ROOT)", with: pathString)
                    ).pathString
                ) ?? $0
            }
        )
    }

    private func updatedHeaderSearchPaths(
        targetID: TargetID,
        oldHeaderSearchPaths: SettingsDictionary.Value?,
        targetToDependenciesMetadata: [TargetID: Set<DependencyMetadata>]
    ) -> SettingsDictionary.Value? {
        let dependenciesHeaderSearchPaths = Set(targetToDependenciesMetadata[targetID]?.flatMap(\.headerSearchPaths) ?? [])
        guard !dependenciesHeaderSearchPaths.isEmpty
        else { return nil }

        var mappedHeaderSearchPaths: [String]
        switch oldHeaderSearchPaths ?? .array(["$(inherited)"]) {
        case let .array(values):
            mappedHeaderSearchPaths = values
        case let .string(value):
            mappedHeaderSearchPaths = value.split(separator: " ").map(String.init)
        }

        for headerSearchPath in dependenciesHeaderSearchPaths.sorted() {
            var mappedHeaderPath: String
            let path = try? AbsolutePath(validating: headerSearchPath)
            if let path {
                mappedHeaderPath = path.isAbsolute ? "$(SRCROOT)/\(path.relative(to: targetID.projectPath).pathString)" : headerSearchPath
            } else {
                mappedHeaderPath = headerSearchPath
            }
            mappedHeaderSearchPaths.append(mappedHeaderPath)
        }

        return .array(mappedHeaderSearchPaths)
    }

    private func updatedOtherSwiftFlags(
        targetID: TargetID,
        oldOtherSwiftFlags: SettingsDictionary.Value?,
        targetToDependenciesMetadata: [TargetID: Set<DependencyMetadata>]
    ) -> SettingsDictionary.Value? {
        guard let dependenciesModuleMaps = targetToDependenciesMetadata[targetID]?.compactMap(\.moduleMapPath),
              !dependenciesModuleMaps.isEmpty
        else { return nil }

        var mappedOtherSwiftFlags: [String]
        switch oldOtherSwiftFlags ?? .array(["$(inherited)"]) {
        case let .array(values):
            mappedOtherSwiftFlags = values
        case let .string(value):
            mappedOtherSwiftFlags = value.split(separator: " ").map(String.init)
        }

        for moduleMap in dependenciesModuleMaps.sorted() {
            mappedOtherSwiftFlags.append(contentsOf: [
                "-Xcc",
                "-fmodule-map-file=$(SRCROOT)/\(moduleMap.relative(to: targetID.projectPath))",
            ])
        }

        return .array(mappedOtherSwiftFlags)
    }

    private func updatedOtherCFlags(
        targetID: TargetID,
        oldOtherCFlags: SettingsDictionary.Value?,
        targetToDependenciesMetadata: [TargetID: Set<DependencyMetadata>]
    ) -> SettingsDictionary.Value? {
        guard let dependenciesModuleMaps = targetToDependenciesMetadata[targetID]?.compactMap(\.moduleMapPath),
              !dependenciesModuleMaps.isEmpty
        else { return nil }

        var mappedOtherCFlags: [String]
        switch oldOtherCFlags ?? .array(["$(inherited)"]) {
        case let .array(values):
            mappedOtherCFlags = values
        case let .string(value):
            mappedOtherCFlags = value.split(separator: " ").map(String.init)
        }

        for moduleMap in dependenciesModuleMaps.sorted() {
            mappedOtherCFlags.append("-fmodule-map-file=$(SRCROOT)/\(moduleMap.relative(to: targetID.projectPath))")
        }

        return .array(mappedOtherCFlags)
    }
}
