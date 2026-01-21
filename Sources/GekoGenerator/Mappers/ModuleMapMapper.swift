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
        target: GraphTarget,
        targetToDependenciesMetadata: inout [TargetID: Set<DependencyMetadata>]
    ) throws {
        let targetID = TargetID(projectPath: target.path, targetName: target.target.name)
        if targetToDependenciesMetadata[targetID] != nil {
            // already computed
            return
        }
        let graphTraverser = GraphTraverser(graph: graph)

        var dependenciesMetadata: Set<DependencyMetadata> = []
        for dependency in target.target.dependencies {
            let dependentProject: Project
            let dependentTarget: GraphTarget
            switch dependency {
            case let .target(name, _, _):
                guard let dependentTargetFromName = graphTraverser.target(path: target.path, name: name) else {
                    throw ModuleMapMapperError.invalidTargetDependency(
                        sourceProject: target.project.path,
                        sourceTarget: target.target.name,
                        dependentTarget: name
                    )
                }

                guard dependentTargetFromName.project.projectType != .cocoapods else { continue }
                dependentProject = target.project
                dependentTarget = dependentTargetFromName
            case let .project(name, path, _, _):
                guard let dependentProjectFromPath = graph.projects[path],
                      let dependentTargetFromName = graphTraverser.target(path: path, name: name)
                else {
                    throw ModuleMapMapperError.invalidProjectTargetDependency(
                        sourceProject: target.project.path,
                        sourceTarget: target.target.name,
                        dependentProject: path,
                        dependentTarget: name
                    )
                }
                guard dependentTargetFromName.project.projectType != .cocoapods else { continue }
                dependentProject = dependentProjectFromPath
                dependentTarget = dependentTargetFromName
            case .framework, .xcframework, .library, .sdk, .xctest, .bundle, .external, .local:
                continue
            }

            try dependenciesModuleMaps(
                graph: graph,
                target: dependentTarget,
                targetToDependenciesMetadata: &targetToDependenciesMetadata
            )

            // direct dependency module map
            let dependencyModuleMapPath: AbsolutePath?

            if case let .string(dependencyModuleMap) = dependentTarget.target.settings?.base[Self.modulemapFileSetting], dependentTarget.project.projectType == .spm {
                let pathString = dependentProject.path.pathString
                dependencyModuleMapPath = try AbsolutePath(
                    validating: dependencyModuleMap
                        .replacingOccurrences(of: "$(PROJECT_DIR)", with: pathString)
                        .replacingOccurrences(of: "$(SRCROOT)", with: pathString)
                        .replacingOccurrences(of: "$(SOURCE_ROOT)", with: pathString)
                )
            } else {
                dependencyModuleMapPath = nil
            }

            var headerSearchPaths: [String]
            switch dependentTarget.target.settings?.base[Self.headerSearchPaths] ?? .array([]) {
            case let .array(values):
                headerSearchPaths = values
            case let .string(value):
                headerSearchPaths = [value]
            }

            headerSearchPaths = headerSearchPaths.map {
                let pathString = dependentProject.path.pathString
                return (
                    try? AbsolutePath(
                        validating: $0
                            .replacingOccurrences(of: "$(PROJECT_DIR)", with: pathString)
                            .replacingOccurrences(of: "$(SRCROOT)", with: pathString)
                            .replacingOccurrences(of: "$(SOURCE_ROOT)", with: pathString)
                    ).pathString
                ) ?? $0
            }

            // indirect dependency module maps
            let dependentTargetID = TargetID(projectPath: dependentProject.path, targetName: dependentTarget.target.name)
            if let indirectDependencyMetadata = targetToDependenciesMetadata[dependentTargetID] {
                dependenciesMetadata.formUnion(indirectDependencyMetadata)
            }

            dependenciesMetadata.insert(
                DependencyMetadata(
                    moduleMapPath: dependencyModuleMapPath,
                    headerSearchPaths: headerSearchPaths
                )
            )
        }

        targetToDependenciesMetadata[targetID] = dependenciesMetadata
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
