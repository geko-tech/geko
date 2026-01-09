import ProjectDescription
import GekoCore
import GekoLoader
import GekoGraph
import GekoSupport

import struct ProjectDescription.AbsolutePath

// MARK: - Dependencies Controller Error

enum DependenciesControllerError: FatalError, Equatable {
    /// Thrown when the same dependency is defined more than once.
    case duplicatedDependency(String, [ProjectDescription.TargetDependency], [ProjectDescription.TargetDependency])
    case duplicatedTreeDependency(String, GekoCore.DependenciesGraph.TreeDependency, GekoCore.DependenciesGraph.TreeDependency)

    /// Thrown when the same project is defined more than once.
    case duplicatedProject(FilePath, ProjectDescription.Project, ProjectDescription.Project)

    /// Thrown when platforms for dependencies to install are not determined in `Dependencies.swift`.
    case noPlatforms

    /// Error type.
    var type: ErrorType {
        switch self {
        case .duplicatedDependency, .duplicatedProject, .noPlatforms, .duplicatedTreeDependency:
            return .abort
        }
    }

    // Error description.
    var description: String {
        switch self {
        case let .duplicatedDependency(name, first, second):
            return """
            The \(name) dependency is defined twice across different dependency managers:
            First: \(first)
            Second: \(second)
            """
        case let .duplicatedTreeDependency(name, first, second):
            return """
            The \(name) dependency is defined twice across different dependency managers:
            First: \(first)
            Second: \(second)
            """
        case let .duplicatedProject(name, first, second):
            return """
            The \(name) project is defined twice across different dependency managers:
            First: \(first)
            Second: \(second)
            """
        case .noPlatforms:
            return "Platforms were not determined. Select platforms in `Dependencies.swift` manifest file."
        }
    }
}

// MARK: - Dependencies Controlling

/// `DependenciesControlling` controls fetching/updating cocoapods and spm dependencies
public protocol DependenciesControlling {
    /// Update dependencies.
    /// - Parameters:
    ///   - path: Directory where project's dependencies will be updated.
    ///   - config: Project manifest config
    ///   - passthroughArguments: Additional arguments to resolve spm
    ///   - cococapodsDependencies: List of cocoapods dependencies to update
    ///   - packageSettings: Custom Swift Package Manager settings
    ///   - repoUpdate: If passed then cocoapods try to update repo
    ///   - deployment: If passed then cocoapods checks that the lock file was not modified during installation.
    func fetch(
        at path: AbsolutePath,
        config: Config,
        passthroughArguments: [String],
        cocoapodsDependencies: CocoapodsDependencies?,
        packageSettings: PackageSettings?,
        repoUpdate: Bool,
        deployment: Bool
    ) async throws -> DependenciesGraph
    
    /// Update dependencies.
    /// - Parameters:
    ///   - path: Directory where project's dependencies will be updated.
    ///   - config: Project manifest config
    ///   - passthroughArguments: Additional arguments to resolve spm
    ///   - cocoapodsDependencies: List of cocoapods dependencies to update
    ///   - packageSettings: Custom Swift Package Manager settings
    func update(
        at path: AbsolutePath,
        config: Config,
        passthroughArguments: [String],
        cocoapodsDependencies: CocoapodsDependencies?,
        packageSettings: GekoGraph.PackageSettings?
    ) async throws -> DependenciesGraph

    /// Save dependencies graph.
    /// - Parameters:
    ///   - dependenciesGraph: The dependencies graph to be saved.
    ///   - path: Directory where dependencies graph will be saved.
    func save(
        dependenciesGraph: GekoGraph.DependenciesGraph,
        to path: AbsolutePath
    ) throws
    
    /// Is dependencies was changed
    /// - Parameters:
    ///    - cocoapodsDependencies: The cocoapods dependecies
    ///    - packageSettings: Custom Swift Package Manager settings
    ///    - path: Directory where project's dependencies will be checked
    ///    - cache: Is cache used
    func needFetch(
        cocoapodsDependencies: CocoapodsDependencies?,
        packageSettings: PackageSettings?,
        path: AbsolutePath,
        cache: Bool
    ) throws -> Bool
}

// MARK: - Dependencies Controller

public final class DependenciesController: DependenciesControlling {
    private let cocoapodsInteractor: CocoapodsInteractor = .init()
    private let swiftPackageManagerInteractor: SwiftPackageManagerInteracting
    private let dependenciesGraphController: DependenciesGraphControlling

    public init(
        swiftPackageManagerInteractor: SwiftPackageManagerInteracting = SwiftPackageManagerInteractor(),
        dependenciesGraphController: DependenciesGraphControlling = DependenciesGraphController()
    ) {
        self.swiftPackageManagerInteractor = swiftPackageManagerInteractor
        self.dependenciesGraphController = dependenciesGraphController
    }
    
    public func fetch(
        at path: AbsolutePath,
        config: Config,
        passthroughArguments: [String],
        cocoapodsDependencies: CocoapodsDependencies?,
        packageSettings: PackageSettings?,
        repoUpdate: Bool,
        deployment: Bool
    ) async throws -> DependenciesGraph {
        try await install(
            at: path,
            config: config,
            cocoapods: cocoapodsDependencies,
            packageSettings: packageSettings,
            passthroughArguments: passthroughArguments,
            shouldUpdate: false,
            repoUpdate: repoUpdate,
            deployment: deployment
        )
    }

    public func update(
        at path: AbsolutePath,
        config: Config,
        passthroughArguments: [String],
        cocoapodsDependencies: CocoapodsDependencies?,
        packageSettings: GekoGraph.PackageSettings?
    ) async throws -> DependenciesGraph {
        try await install(
            at: path,
            config: config,
            cocoapods: cocoapodsDependencies,
            packageSettings: packageSettings,
            passthroughArguments: passthroughArguments,
            shouldUpdate: true,
            repoUpdate: true,
            deployment: false
        )
    }

    public func save(
        dependenciesGraph: GekoGraph.DependenciesGraph,
        to path: AbsolutePath
    ) throws {
        try dependenciesGraphController.save(dependenciesGraph, to: path)
    }

    public func needFetch(
        cocoapodsDependencies: CocoapodsDependencies?,
        packageSettings: PackageSettings?,
        path: AbsolutePath,
        cache: Bool
    ) throws -> Bool {
        var needFetch = false
        if let cocoapodsDependencies = cocoapodsDependencies {
            let result = try cocoapodsInteractor.needFetch(dependencies: cocoapodsDependencies, path: path)
            needFetch = needFetch || result
        }
        if packageSettings != nil {
            let result = try swiftPackageManagerInteractor.needFetch(path: path)
            needFetch = needFetch || result
        }

        // In case if swiftinterfaces dir exist and we will not use cache
        if !cache && FileHandler.shared.exists(path.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftinterfacesDirectoryName,
        ])) {
            needFetch = true
        }

        return needFetch
    }

    // MARK: - Helpers

    private func install(
        at path: AbsolutePath,
        config: GekoGraph.Config,
        cocoapods: CocoapodsDependencies?,
        packageSettings: PackageSettings?,
        passthroughArguments: [String],
        shouldUpdate: Bool,
        repoUpdate: Bool,
        deployment: Bool
    ) async throws -> GekoCore.DependenciesGraph {
        let manifestDirectory = path
            .appending(component: Constants.gekoDirectoryName)
        let dependenciesDirectory = manifestDirectory
            .appending(component: Constants.DependenciesDirectory.name)

        let generatorPaths = GeneratorPaths(manifestDirectory: manifestDirectory)

        var dependenciesGraph = GekoCore.DependenciesGraph.none

        if let packageSettings = packageSettings {
            // Passthrough arguments come last so they override config arguments (last flag wins)
            let mergedArguments = config.installOptions.passthroughSwiftPackageManagerArguments + passthroughArguments
            
            let swiftPackageManagerDependenciesGraph = try swiftPackageManagerInteractor.install(
                dependenciesDirectory: dependenciesDirectory,
                packageSettings: packageSettings,
                arguments: mergedArguments,
                shouldUpdate: shouldUpdate,
                swiftToolsVersion: config.swiftVersion
            )

            dependenciesGraph = try dependenciesGraph.merging(with: swiftPackageManagerDependenciesGraph)
        } else {
            try swiftPackageManagerInteractor.clean(dependenciesDirectory: dependenciesDirectory)
        }

        if let cocoapodsDependencies = cocoapods {
            let cocoapodsGraph = try await cocoapodsInteractor.install(
                path: path,
                dependenciesDirectory: dependenciesDirectory,
                generatorPaths: generatorPaths,
                config: config,
                dependencies: cocoapodsDependencies,
                shouldUpdate: shouldUpdate,
                repoUpdate: repoUpdate,
                deployment: deployment
            )

            dependenciesGraph = try dependenciesGraph.merging(with: cocoapodsGraph)
        } else {
            try cocoapodsInteractor.clean(dependenciesDirectory: dependenciesDirectory)
        }

        // Cleanup folder with swiftinterfaces on each fetch
        let swiftinterfacesDir = path.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftinterfacesDirectoryName,
        ])
        try FileHandler.shared.delete(swiftinterfacesDir)

        return dependenciesGraph
    }
}

extension GekoCore.DependenciesGraph {
    public func merging(with other: Self) throws -> Self {
        var mergedExternalDependencies: [String: [ProjectDescription.TargetDependency]] =
            externalDependencies

        for (name, dependency) in other.externalDependencies {
            if let alreadyPresent = mergedExternalDependencies[name] {
                throw DependenciesControllerError.duplicatedDependency(name, alreadyPresent, dependency)
            }
            mergedExternalDependencies[name] = dependency
        }

        let mergedExternalProjects = try other.externalProjects.reduce(into: externalProjects) { result, entry in
            if let alreadyPresent = result[entry.key] {
                throw DependenciesControllerError.duplicatedProject(entry.key, alreadyPresent, entry.value)
            }
            result[entry.key] = entry.value
        }

        let mergedExternalFrameworkDependencies = try other.externalFrameworkDependencies
            .reduce(into: externalFrameworkDependencies) { result, entry in
                if let alreadyPresent = result[entry.key] {
                    throw DependenciesControllerError.duplicatedDependency(entry.key.pathString, alreadyPresent, entry.value)
                }
                result[entry.key] = entry.value
            }

        let mergedTree = try other.tree
            .reduce(into: tree) { result, entry in
                if let alreadyPresent = result[entry.key] {
                    throw DependenciesControllerError.duplicatedTreeDependency(entry.key, alreadyPresent, entry.value)
                }
                result[entry.key] = entry.value
            }

        return .init(
            externalDependencies: mergedExternalDependencies,
            externalProjects: mergedExternalProjects,
            externalFrameworkDependencies: mergedExternalFrameworkDependencies,
            tree: mergedTree
        )
    }

    public func deepMerging(with other: Self) throws -> Self {
        var mergedExternalDependencies: [String: [ProjectDescription.TargetDependency]] =
            externalDependencies

        for (name, dependency) in other.externalDependencies {
            if let alreadyPresent = mergedExternalDependencies[name] {
                mergedExternalDependencies[name] = alreadyPresent + dependency
            } else {
                mergedExternalDependencies[name] = dependency
            }
        }

        let mergedExternalProjects = other.externalProjects.reduce(into: externalProjects) { result, entry in
            if let alreadyPresent = result[entry.key] {
                result[entry.key] = mergeProjects(
                    alreadyPresent,
                    entry.value,
                    path: entry.key
                )
                return
            }
            result[entry.key] = entry.value
        }

        let mergedExternalFrameworkDependencies = other.externalFrameworkDependencies
            .reduce(into: externalFrameworkDependencies) { result, entry in
                if let alreadyPresent = result[entry.key] {
                    result[entry.key] = alreadyPresent + entry.value
                } else {
                    result[entry.key] = entry.value
                }
            }

        let mergedTree = try other.tree
            .reduce(into: tree) { result, entry in
                if let alreadyPresent = result[entry.key] {
                    if alreadyPresent.version != entry.value.version {
                        throw DependenciesControllerError.duplicatedTreeDependency(entry.key, alreadyPresent, entry.value)
                    }

                    result[entry.key] = .init(
                        version: alreadyPresent.version,
                        dependencies: Array(Set(alreadyPresent.dependencies + entry.value.dependencies))
                    )
                } else {
                    result[entry.key] = entry.value
                }
            }

        return .init(
            externalDependencies: mergedExternalDependencies,
            externalProjects: mergedExternalProjects,
            externalFrameworkDependencies: mergedExternalFrameworkDependencies,
            tree: mergedTree
        )
    }

    private func mergeProjects(
        _ first: ProjectDescription.Project,
        _ second: ProjectDescription.Project,
        path: FilePath
    ) -> ProjectDescription.Project {
        var result = first
        result.name = path.basename
        result.targets.append(contentsOf: second.targets)
        result.schemes.append(contentsOf: second.schemes)
        result.additionalFiles.append(contentsOf: second.additionalFiles)
        return result
    }
}
