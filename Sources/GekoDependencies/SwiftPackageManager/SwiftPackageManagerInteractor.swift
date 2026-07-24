import ProjectDescription
import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import Yams

// MARK: - Swift Package Manager Interactor Errors

enum SwiftPackageManagerInteractorError: FatalError, Equatable {
    /// Thrown when `Package.swift` cannot be found after `Swift Package Manager` installation.
    case packageSwiftNotFound
    /// Thrown when `Package.resolved` cannot be found after `Swift Package Manager` installation.
    case packageResolvedNotFound
    /// Thrown when `.build` cannot be found after `Swift Package Manager` installation.
    case buildDirectoryNotFound

    /// Error type.
    var type: ErrorType {
        switch self {
        case .packageSwiftNotFound,
             .packageResolvedNotFound,
             .buildDirectoryNotFound:
            return .bug
        }
    }

    /// Error description.
    var description: String {
        switch self {
        case .packageSwiftNotFound:
            return "The Package.swift file was not found after resolving the dependencies using the Swift Package Manager."
        case .packageResolvedNotFound:
            return "The Package.resolved lockfile was not found after resolving the dependencies using the Swift Package Manager."
        case .buildDirectoryNotFound:
            return "The .build directory was not found after resolving the dependencies using the Swift Package Manager"
        }
    }
}

// MARK: - Swift Package Manager Interacting

public protocol SwiftPackageManagerInteracting {
    /// Installs `Swift Package Manager` dependencies.
    /// - Parameters:
    ///   - dependenciesDirectory: The path to the `Geko/Dependencies/` directory.
    ///   - packageSettings: User defined `Swift Package Manager` settings.
    ///   - shouldUpdate: Indicates whether dependencies should be updated or fetched based on the lockfile.
    ///   - swiftToolsVersion: The Swift tools version written to `Package.swift` and used when generating dependency build settings.
    ///     If `nil`, `Package.swift` is not modified.
    func install(
        dependenciesDirectory: AbsolutePath,
        packageSettings: PackageSettings,
        arguments: [String],
        shouldUpdate: Bool,
        swiftToolsVersion: Version?
    ) throws -> GekoCore.DependenciesGraph

    /// Removes all cached `Swift Package Manager` dependencies.
    /// - Parameter dependenciesDirectory: The path to the `Geko/Dependencies/` directory.
    func clean(dependenciesDirectory: AbsolutePath) throws
    
    func needFetch(path: AbsolutePath) throws -> Bool 
}

// MARK: - Swift Package Manager Interactor

public final class SwiftPackageManagerInteractor: SwiftPackageManagerInteracting {
    private let fileHandler: FileHandling
    private let swiftPackageManagerController: SwiftPackageManagerControlling
    private let swiftPackageManagerGraphGenerator: SwiftPackageManagerGraphGenerating

    public init(
        fileHandler: FileHandling = FileHandler.shared,
        swiftPackageManagerController: SwiftPackageManagerControlling = SwiftPackageManagerController(),
        swiftPackageManagerGraphGenerator: SwiftPackageManagerGraphGenerating = SwiftPackageManagerGraphGenerator(
            swiftPackageManagerController: SwiftPackageManagerController()
        )
    ) {
        self.fileHandler = fileHandler
        self.swiftPackageManagerController = swiftPackageManagerController
        self.swiftPackageManagerGraphGenerator = swiftPackageManagerGraphGenerator
    }

    public func install(
        dependenciesDirectory: AbsolutePath,
        packageSettings: PackageSettings,
        arguments: [String],
        shouldUpdate: Bool,
        swiftToolsVersion: Version?
    ) throws -> GekoCore.DependenciesGraph {
        logger.info("Installing Swift Package Manager dependencies.", metadata: .subsection)

        let pathsProvider = SwiftPackageManagerPathsProvider(dependenciesDirectory: dependenciesDirectory)

        if let swiftToolsVersion = swiftToolsVersion {
            try swiftPackageManagerController.setToolsVersion(
                at: pathsProvider.packageDirectory,
                to: swiftToolsVersion
            )
        }

        try logPackageManifest(pathsProvider: pathsProvider)

        if shouldUpdate {
            try swiftPackageManagerController.update(at: pathsProvider.packageDirectory, arguments: arguments, printOutput: true)
        } else {
            try swiftPackageManagerController.resolve(
                at: pathsProvider.packageDirectory,
                arguments: arguments,
                printOutput: true
            )
        }

        try validateResolvedDependencies(pathsProvider: pathsProvider)
        try saveLockfile(pathsProvider: pathsProvider)
        
        let resolvedDependenciesVersions: [String: String?]
        let packageResolvedPath = pathsProvider.packageResolvedPath
        /// If Package.resolved exists then there are external dependencies
        if FileHandler.shared.exists(packageResolvedPath) {
            let resolvedData = try FileHandler.shared.readFile(packageResolvedPath)
            let resolvedModel: SwiftPackageManagerResolvedState = try parseJson(resolvedData, context: .file(path: packageResolvedPath))
            resolvedDependenciesVersions = Dictionary(uniqueKeysWithValues: zip(resolvedModel.pins.map { $0.identity }, resolvedModel.pins.map { $0.state.version }))
        /// otherwise we have only local dependencies
        } else {
            resolvedDependenciesVersions = [:]
        }
       
        let dependenciesGraph = try swiftPackageManagerGraphGenerator.generate(
            at: pathsProvider.buildDirectory,
            productTypes: packageSettings.productTypes,
            baseSettings: packageSettings.baseSettings,
            targetSettings: packageSettings.targetSettings,
            swiftToolsVersion: swiftToolsVersion,
            projectOptions: packageSettings.projectOptions,
            resolvedDependenciesVersions: resolvedDependenciesVersions
        )

        logger.info("Swift Package Manager dependencies installed successfully.", metadata: .subsection)

        return dependenciesGraph
    }

    public func clean(dependenciesDirectory: AbsolutePath) throws {
        let pathsProvider = SwiftPackageManagerPathsProvider(dependenciesDirectory: dependenciesDirectory)
        try fileHandler.delete(pathsProvider.buildDirectory)
    }
    
    public func needFetch(path: AbsolutePath) throws -> Bool {
        let clock = WallClock()
        let timer = clock.startTimer()

        let sandboxPackageFilePath = path.appending(components: [
            Constants.GekoUserCacheDirectory.name,
            Constants.DependenciesDirectory.packageSandboxName
        ])
        
        let packageResolvedFilePath = path.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageResolvedName
        ])
        
        let packagePath = path.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageSwiftName
        ])
        
        let workspaceStatePath = path.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        
        guard FileHandler.shared.exists(sandboxPackageFilePath) else {
            logger.debug("PackageSandbox.lock is not present. Fetching...")
            return true
        }
        
        guard FileHandler.shared.exists(workspaceStatePath) else {
            logger.debug("workspace-state.json is not present. Fetching...")
            return true
        }
        
        guard FileHandler.shared.exists(packagePath) else {
            logger.debug("Package.swift is not present. Fetching...")
            return true
        }
        
        let localPackagesPaths = try localPackagesPaths(workspaceStatePath: workspaceStatePath)
        let newDependecies = try makeLockfile(manifestPath: packagePath, resolvedPath: packageResolvedFilePath, localPackagesPaths: localPackagesPaths)
        
        let oldDependenciesData = try FileHandler.shared.readTextFile(sandboxPackageFilePath)
        let oldDependecies = try YAMLDecoder().decode(SwiftPackageManagerDependenciesSandbox.self, from: oldDependenciesData)
        
        let result = newDependecies != oldDependecies
        
        if result {
            logger.debug("PackageSandbox.lock does not match requested dependencies. Fetching...")
        } else {
            logger.debug("PackageSandbox.lock matches requested dependencies. Skipping fetch.")
        }

        logger.debug("SPM needFetch check time: \(timer.stop())")
        
        return result
    }

    // MARK: - Installation

    private func logPackageManifest(
        pathsProvider: SwiftPackageManagerPathsProvider
    ) throws {
        let manifestContent = try fileHandler.readTextFile(pathsProvider.packageSwiftPath)
        logger.debug("Package.swift:", metadata: .subsection)
        logger.debug("\(manifestContent)")
    }

    private func validateResolvedDependencies(pathsProvider: SwiftPackageManagerPathsProvider) throws {
        guard fileHandler.exists(pathsProvider.packageSwiftPath) else {
            throw SwiftPackageManagerInteractorError.packageSwiftNotFound
        }
        guard fileHandler.exists(pathsProvider.buildDirectory) else {
            throw SwiftPackageManagerInteractorError.buildDirectoryNotFound
        }
    }
    
    private func saveLockfile(pathsProvider: SwiftPackageManagerPathsProvider) throws {
        let localPackagesPaths = try localPackagesPaths(workspaceStatePath: pathsProvider.workspaceStatePath)
        let lockfile = try makeLockfile(
            manifestPath: pathsProvider.packageSwiftPath,
            resolvedPath: pathsProvider.packageResolvedPath,
            localPackagesPaths: localPackagesPaths
        )

        let encoder = YAMLEncoder()
        encoder.options.sortKeys = true
        let encodedLockfile = try encoder.encode(lockfile)
        
        try FileHandler.shared.write(encodedLockfile, path: pathsProvider.lockfilePath, atomically: true)
    }
    
    private func localPackagesPaths(workspaceStatePath: AbsolutePath) throws -> [AbsolutePath] {
        let data = try FileHandler.shared.readFile(workspaceStatePath)
        let workspaceState: SwiftPackageManagerWorkspaceState = try parseJson(data, context: .file(path: workspaceStatePath))
        var localPackagesPaths: [AbsolutePath]
        localPackagesPaths = try workspaceState.object.dependencies.compactMap(context: .concurrent) { dependency in
            switch dependency.packageRef.kind {
            case "local", "fileSystem", "localSourceControl":
                guard let stringPath = dependency.packageRef.path ?? dependency.packageRef.location else {
                    throw SwiftPackageManagerGraphGeneratorError.missingPathInLocalSwiftPackage(dependency.packageRef.name)
                }
                return try AbsolutePath(validating: stringPath).appending(component: Constants.DependenciesDirectory.packageSwiftName)
            default:
                return nil
            }
        }
        return localPackagesPaths.filter { FileHandler.shared.exists($0) }
    }
    
    private func makeLockfile(
        manifestPath: AbsolutePath,
        resolvedPath: AbsolutePath,
        localPackagesPaths: [AbsolutePath]
    ) throws -> SwiftPackageManagerDependenciesSandbox {
        let hasher = ContentHasher()
        var resultDict: [String: String] = [:]
        resultDict[manifestPath.pathString] = try hasher.hash(path: manifestPath)
        /// If Package.resolved not exists then there are no external dependencies, only local
        if FileHandler.shared.exists(resolvedPath) {
            resultDict[resolvedPath.pathString] = try hasher.hash(path: resolvedPath)
        }
        for packagePath in localPackagesPaths.sorted() {
            resultDict[packagePath.pathString] = try hasher.hash(path: packagePath)
        }
        return SwiftPackageManagerDependenciesSandbox(filesHashes: resultDict)
    }

}

// MARK: - Models

private struct SwiftPackageManagerPathsProvider {
    let packageDirectory: AbsolutePath
    let packageSwiftPath: AbsolutePath
    let packageResolvedPath: AbsolutePath
    let workspaceStatePath: AbsolutePath
    let buildDirectory: AbsolutePath
    let lockfilePath: AbsolutePath

    init(dependenciesDirectory: AbsolutePath) {
        let gekoDirectory = dependenciesDirectory.removingLastComponent()
        packageDirectory = gekoDirectory
        packageSwiftPath = gekoDirectory.appending(component: Constants.DependenciesDirectory.packageSwiftName)
        packageResolvedPath = gekoDirectory.appending(component: Constants.DependenciesDirectory.packageResolvedName)
        buildDirectory = gekoDirectory.appending(component: Constants.DependenciesDirectory.packageBuildDirectoryName)
        workspaceStatePath = buildDirectory.appending(component: Constants.DependenciesDirectory.workspaceStateName)
        lockfilePath = gekoDirectory.removingLastComponent().appending(components: [
            Constants.GekoUserCacheDirectory.name,
            Constants.DependenciesDirectory.packageSandboxName
        ])
    }
}
