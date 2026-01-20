import ProjectDescription
import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import Yams

// MARK: - Swift Package Manager Interactor Errors

enum SwiftPackageManagerInteractorError: FatalError, Equatable {
    /// Thrown when `Package.swift` cannot be found in temporary directory after `Swift Package Manager` installation.
    case packageSwiftNotFound
    /// Thrown when `Package.resolved` cannot be found in temporary directory after `Swift Package Manager` installation.
    case packageResolvedNotFound
    /// Thrown when `.build` directory cannot be found in temporary directory after `Swift Package Manager` installation.
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
    ///   - dependenciesDirectory: The path to the directory that contains the `Geko/Dependencies/` directory.
    ///   - packageSettings: User defined `Swift Package Manager` settings.
    ///   - shouldUpdate: Indicates whether dependencies should be updated or fetched based on the lockfile.
    ///   - swiftToolsVersion: The version of Swift tools that will be used to resolve dependencies. If `nil` is passed then the
    /// environment’s version will be used.
    func install(
        dependenciesDirectory: AbsolutePath,
        packageSettings: PackageSettings,
        arguments: [String],
        shouldUpdate: Bool,
        swiftToolsVersion: Version?
    ) throws -> GekoCore.DependenciesGraph

    /// Removes all cached `Swift Package Manager` dependencies.
    /// - Parameter dependenciesDirectory: The path to the directory that contains the `Geko/Dependencies/` directory.
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

        try loadDependencies(pathsProvider: pathsProvider, packageSettings: packageSettings, swiftToolsVersion: swiftToolsVersion)

        if shouldUpdate {
            try swiftPackageManagerController.update(at: pathsProvider.destinationSwiftPackageManagerDirectory, arguments: arguments, printOutput: true)
        } else {
            try swiftPackageManagerController.resolve(
                at: pathsProvider.destinationSwiftPackageManagerDirectory,
                arguments: arguments,
                printOutput: true
            )
        }

        try saveDependencies(pathsProvider: pathsProvider)
        try saveLockfile(pathsProvider: pathsProvider)
        
        let resolvedDependenciesVersions: [String: String?]
        let packageResolvedPath = pathsProvider.destinationPackageResolvedPath
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
            at: pathsProvider.destinationBuildDirectory,
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
        try fileHandler.delete(pathsProvider.destinationSwiftPackageManagerDirectory)
        try fileHandler.delete(pathsProvider.destinationPackageResolvedPath)
    }
    
    public func needFetch(path: AbsolutePath) throws -> Bool {
        let clock = WallClock()
        let timer = clock.startTimer()

        let sandboxPackageFilePath = path.appending(components: [
            Constants.GekoUserCacheDirectory.name,
            Constants.DependenciesDirectory.packageSandboxName
        ])
        
        let dependenciesFilePath = path.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.dependenciesFileName
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
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        
        let mainDependenciesPath = {
            if FileHandler.shared.exists(dependenciesFilePath) {
                return dependenciesFilePath
            } else {
                return packagePath
            }
        }()
        
        guard FileHandler.shared.exists(sandboxPackageFilePath) else {
            logger.debug("PackageSandbox.lock is not present. Fetching...")
            return true
        }
        
        guard FileHandler.shared.exists(workspaceStatePath) else {
            logger.debug("workspace-state.json is not present. Fetching...")
            return true
        }
        
        guard FileHandler.shared.exists(mainDependenciesPath) else {
            logger.debug("Dependencies.swift or Package.swift is not present. Fetching...")
            return true
        }
        
        let localPackagesPaths = try localPackagesPaths(workspaceStatePath: workspaceStatePath)
        let newDependecies = try makeLockfile(manifestPath: mainDependenciesPath, resolvedPath: packageResolvedFilePath, localPackagesPaths: localPackagesPaths)
        
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

    /// Loads lockfile and dependencies into working directory if they had been saved before.
    private func loadDependencies(
        pathsProvider: SwiftPackageManagerPathsProvider,
        packageSettings: PackageSettings,
        swiftToolsVersion: Version?
    ) throws {
        let version = try swiftToolsVersion ??
            Version(versionString: try System.shared.swiftVersion(), usesLenientParsing: true)

        // copy `Package.resolved` directory from lockfiles folder
        if fileHandler.exists(pathsProvider.destinationPackageResolvedPath) {
            try copy(
                from: pathsProvider.destinationPackageResolvedPath,
                to: pathsProvider.temporaryPackageResolvedPath
            )
        }

        // create `Package.swift`
        let packageManifestPath = pathsProvider.destinationPackageSwiftPath
        try fileHandler.createFolder(packageManifestPath.removingLastComponent())

        if fileHandler.exists(packageManifestPath) {
            try fileHandler.replace(packageManifestPath, with: pathsProvider.sourcePackageSwiftPath)
        } else {
            try fileHandler.copy(from: pathsProvider.sourcePackageSwiftPath, to: packageManifestPath)
        }

        // set `swift-tools-version` in `Package.swift`
        try swiftPackageManagerController.setToolsVersion(
            at: pathsProvider.destinationSwiftPackageManagerDirectory,
            to: version
        )

        let manifestContent = try fileHandler.readTextFile(packageManifestPath)
        logger.debug("Package.swift:", metadata: .subsection)
        logger.debug("\(manifestContent)")
    }

    /// Saves lockfile resolved dependencies in `Geko/Dependencies` directory.
    private func saveDependencies(pathsProvider: SwiftPackageManagerPathsProvider) throws {
        guard fileHandler.exists(pathsProvider.destinationPackageSwiftPath) else {
            throw SwiftPackageManagerInteractorError.packageSwiftNotFound
        }
        guard fileHandler.exists(pathsProvider.destinationBuildDirectory) else {
            throw SwiftPackageManagerInteractorError.buildDirectoryNotFound
        }

        if fileHandler.exists(pathsProvider.temporaryPackageResolvedPath) {
            try copy(
                from: pathsProvider.temporaryPackageResolvedPath,
                to: pathsProvider.destinationPackageResolvedPath
            )
        }

        // remove temporary files
        try? FileHandler.shared.delete(pathsProvider.temporaryPackageResolvedPath)
    }
    
    private func saveLockfile(pathsProvider: SwiftPackageManagerPathsProvider) throws {
        let localPackagesPaths = try localPackagesPaths(workspaceStatePath: pathsProvider.destinationWorkspaceStatePath)
        let lockfile = try makeLockfile(
            manifestPath: pathsProvider.destinationDependenciesPath,
            resolvedPath: pathsProvider.destinationPackageResolvedPath,
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

    // MARK: - Helpers

    private func copy(from fromPath: AbsolutePath, to toPath: AbsolutePath) throws {
        if fileHandler.exists(toPath) {
            try fileHandler.replace(toPath, with: fromPath)
        } else {
            try fileHandler.createFolder(toPath.removingLastComponent())
            try fileHandler.copy(from: fromPath, to: toPath)
        }
    }
}

// MARK: - Models

private struct SwiftPackageManagerPathsProvider {
    let destinationSwiftPackageManagerDirectory: AbsolutePath
    let destinationPackageSwiftPath: AbsolutePath
    let destinationDependenciesPath: AbsolutePath
    let destinationPackageResolvedPath: AbsolutePath
    let destinationWorkspaceStatePath: AbsolutePath
    let destinationBuildDirectory: AbsolutePath
    let sourcePackageSwiftPath: AbsolutePath
    let lockfilePath: AbsolutePath

    let temporaryPackageResolvedPath: AbsolutePath

    init(dependenciesDirectory: AbsolutePath) {
        let gekoDirectory = dependenciesDirectory.removingLastComponent()
        destinationPackageSwiftPath = dependenciesDirectory
            .appending(component: Constants.DependenciesDirectory.swiftPackageManagerDirectoryName)
            .appending(component: Constants.DependenciesDirectory.packageSwiftName)
        if FileHandler.shared.exists(gekoDirectory.appending(component: Constants.DependenciesDirectory.dependenciesFileName)) {
            destinationDependenciesPath = gekoDirectory.appending(component: Constants.DependenciesDirectory.dependenciesFileName)
        } else {
            destinationDependenciesPath = gekoDirectory.appending(component: Constants.DependenciesDirectory.packageSwiftName)
        }
        destinationPackageResolvedPath = gekoDirectory
            .appending(component: Constants.DependenciesDirectory.packageResolvedName)
        destinationSwiftPackageManagerDirectory = dependenciesDirectory
            .appending(component: Constants.DependenciesDirectory.swiftPackageManagerDirectoryName)
        destinationWorkspaceStatePath = dependenciesDirectory.appending(components: [
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName,
            Constants.DependenciesDirectory.packageBuildDirectoryName,
            Constants.DependenciesDirectory.workspaceStateName
        ])
        destinationBuildDirectory = destinationSwiftPackageManagerDirectory.appending(component: Constants.DependenciesDirectory.packageBuildDirectoryName)
        sourcePackageSwiftPath = gekoDirectory.appending(component: Constants.DependenciesDirectory.packageSwiftName)

        temporaryPackageResolvedPath = destinationSwiftPackageManagerDirectory
            .appending(component: Constants.DependenciesDirectory.packageResolvedName)
        lockfilePath = gekoDirectory.removingLastComponent().appending(components: [
            Constants.GekoUserCacheDirectory.name,
            Constants.DependenciesDirectory.packageSandboxName
        ])
    }
}
