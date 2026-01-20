import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

public class CompiledManifestLoader: ManifestLoading {

    // MARK: Static

    static let startManifestToken = "GEKO_MANIFEST_START"
    static let endManifestToken = "GEKO_MANIFEST_END"

    //MARK: Dependencies

    private let clock = WallClock()
    private let decoder = JSONDecoder()
    private var plugins: Plugins = .none
    private let resourceLocator: ResourceLocating
    private let manifestFilesLocator: ManifestFilesLocating
    private let helpersDirectoryLocator: HelpersDirectoryLocating
    private let environment: Environmenting
    private let cacheDirectoryProviderFactory: CacheDirectoriesProviderFactoring
    private let projectDescriptionHelpersBuilderFactory: ProjectDescriptionHelpersBuilderFactoring
    private let projectDescriptionHelpersHasher: ProjectDescriptionHelpersHashing
    private let xcodeController: XcodeControlling
    private let swiftPackageManagerController: SwiftPackageManagerControlling
    private let fileHandler: FileHandling
    private let system: Systeming

    private let cacheDirectory: AbsolutePath
    @Atomic private var pluginsHashCache: String?

    public convenience init(helpersHasher: ProjectDescriptionHelpersHashing = ProjectDescriptionHelpersHasher()) {
        self.init(
            environment: Environment.shared,
            resourceLocator: ResourceLocator(),
            manifestFilesLocator: ManifestFilesLocator(),
            helpersDirectoryLocator: HelpersDirectoryLocator(),
            cacheDirectoryProviderFactory: CacheDirectoriesProviderFactory(),
            projectDescriptionHelpersBuilderFactory: ProjectDescriptionHelpersBuilderFactory(helpersHasher: helpersHasher),
            projectDescriptionHelpersHasher: helpersHasher,
            xcodeController: XcodeController.shared,
            swiftPackageManagerController: SwiftPackageManagerController(),
            fileHandler: FileHandler.shared,
            system: System.shared
        )
    }

    init(
        environment: Environmenting,
        resourceLocator: ResourceLocating,
        manifestFilesLocator: ManifestFilesLocating,
        helpersDirectoryLocator: HelpersDirectoryLocating,
        cacheDirectoryProviderFactory: CacheDirectoriesProviderFactoring,
        projectDescriptionHelpersBuilderFactory: ProjectDescriptionHelpersBuilderFactoring,
        projectDescriptionHelpersHasher: ProjectDescriptionHelpersHashing,
        xcodeController: XcodeControlling,
        swiftPackageManagerController: SwiftPackageManagerControlling,
        fileHandler: FileHandling,
        system: Systeming
    ) {
        self.environment = environment
        self.resourceLocator = resourceLocator
        self.manifestFilesLocator = manifestFilesLocator
        self.helpersDirectoryLocator = helpersDirectoryLocator
        self.cacheDirectoryProviderFactory = cacheDirectoryProviderFactory
        self.projectDescriptionHelpersBuilderFactory = projectDescriptionHelpersBuilderFactory
        self.projectDescriptionHelpersHasher = projectDescriptionHelpersHasher
        self.xcodeController = xcodeController
        self.swiftPackageManagerController = swiftPackageManagerController
        self.cacheDirectory = try! cacheDirectoryProviderFactory.cacheDirectories(config: nil).cacheDirectory(for: .manifests)
        self.fileHandler = fileHandler
        self.system = system
    }

    public func loadConfig(at path: AbsolutePath) throws -> ProjectDescription.Config {
        try loadManifest(.config, at: path)
    }

    public func loadProject(at path: AbsolutePath) throws -> ProjectDescription.Project {
        try loadManifest(.project, at: path)
    }

    public func loadWorkspace(at path: AbsolutePath) throws -> ProjectDescription.Workspace {
        try loadManifest(.workspace, at: path)
    }

    public func loadTemplate(at path: AbsolutePath) throws -> ProjectDescription.Template {
        try loadManifest(.template, at: path)
    }

    public func loadDependencies(at path: AbsolutePath) throws -> ProjectDescription.Dependencies {
        let dependencyPath = path.appending(components: Constants.gekoDirectoryName)
        return try loadManifest(.dependencies, at: dependencyPath)
    }

    public func loadPackageSettings(at path: AbsolutePath) throws -> ProjectDescription.PackageSettings {
        let packageManifestPath = path.appending(components: Constants.gekoDirectoryName)
        do {
            return try loadManifest(.package, at: packageManifestPath)
        } catch let error as ManifestLoaderError {
            switch error {
            case let .manifestLoadingFailed(path: _, data: data, context: _):
                if data.count == 0 {
                    return PackageSettings()
                } else {
                    throw error
                }
            default:
                throw error
            }
        }
    }

    public func loadPlugin(at path: AbsolutePath) throws -> ProjectDescription.Plugin {
        try loadManifest(.plugin, at: path)
    }

    public func manifests(at path: AbsolutePath) -> Set<Manifest> {
        Set(manifestFilesLocator.locateManifests(at: path).map(\.0))
    }

    public func validateHasProjectOrWorkspaceManifest(at path: AbsolutePath) throws {
        let manifests = manifests(at: path)
        guard manifests.contains(.workspace) || manifests.contains(.project) else {
            throw ManifestLoaderError.manifestNotFound(path)
        }
    }

    public func register(plugins: GekoGraph.Plugins) throws {
        pluginsHashCache = try calculatePluginsHash(for: plugins)
        self.plugins = plugins
    }

    public func cleanupOldManifests() throws -> [SideEffectDescriptor] {
        guard let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: clock.now) else { return [] }

        return try fileHandler
            .contentsOfDirectory(cacheDirectory)
            .compactMap(context: .concurrent) { path in
                let accessDate = try fileHandler.fileAccessDate(path: path)
                guard
                    fileHandler.isFolder(path),
                    accessDate < oneWeekAgo
                else { return nil }
                return .directory(DirectoryDescriptor(path: path, state: .absent))
            }
    }
}

// MARK: - Private methods

extension CompiledManifestLoader {
    private func manifestPath(
        _ manifest: Manifest,
        at path: AbsolutePath
    ) throws -> AbsolutePath {
        let manifestPath = path.appending(component: manifest.fileName(path))

        guard fileHandler.exists(manifestPath) else {
            throw ManifestLoaderError.manifestNotFound(manifest, path)
        }

        return manifestPath
    }

    private func projectDescriptionHelpersArguments(
        manifest: Manifest,
        at path: AbsolutePath,
        cacheDirectory: AbsolutePath
    ) throws -> [String] {
        let projectDescriptionHelpersCacheDirectory =
            try cacheDirectoryProviderFactory
            .cacheDirectories(config: nil)
            .cacheDirectory(for: .projectDescriptionHelpers)
        let projectDescriptionPath = try resourceLocator.projectDescription()
        let searchPaths = ProjectDescriptionSearchPaths.paths(for: projectDescriptionPath)

        switch manifest {
        case .config, .plugin:
            return []
        case .dependencies,
            .project,
            .template,
            .workspace,
            .package:
            let args: [String] =  try projectDescriptionHelpersBuilderFactory.projectDescriptionHelpersBuilder(
                cacheDirectory: projectDescriptionHelpersCacheDirectory
            ).build(
                at: path,
                projectDescriptionSearchPaths: searchPaths,
                projectDescriptionHelperPlugins: plugins.projectDescriptionHelpers
            ).flatMap {
                [
                    "-I", $0.path.parentDirectory.pathString,
                    "-L", $0.path.parentDirectory.pathString,
                    "-F", $0.path.parentDirectory.pathString,
                    "-l\($0.name)",
                    "-Xlinker", "-rpath",
                    "-Xlinker", searchPaths.librarySearchPath.pathString,
                    "-Xlinker", "-rpath",
                    "-Xlinker", $0.path.parentDirectory.pathString,
                ]
            }
            return args
        }
    }

    // swiftlint:disable:next function_body_length
    private func buildArguments(
        _ manifest: Manifest,
        at path: AbsolutePath,
        manifestPath: AbsolutePath,
        manifestExtensions: [AbsolutePath],
        to destinationPath: AbsolutePath,
        projectDescriptionHelperArguments: [String]
    ) throws -> [String] {
        let projectDescriptionPath = try resourceLocator.projectDescription()
        let searchPaths = ProjectDescriptionSearchPaths.paths(for: projectDescriptionPath)
        let frameworkName: String
        switch manifest {
        case .config,
            .plugin,
            .dependencies,
            .project,
            .template,
            .workspace,
            .package:
            frameworkName = "ProjectDescription"
        }

#if DEBUG && !Xcode || os(Linux)
            let projectDescriptionFlags: [String] = [
                "-L", searchPaths.librarySearchPath.pathString,
                "-l\(frameworkName)",
            ]
#else
            let projectDescriptionFlags: [String] = [
                "-F", searchPaths.frameworkSearchPath.pathString,
                "-framework", frameworkName,
            ]
#endif

#if os(macOS)
        var arguments = ["/usr/bin/xcrun"]
#else
        var arguments: [String] = []
#endif

        arguments += [
            "swiftc",
            "-Onone",
            "-o", destinationPath.pathString,
            "-suppress-warnings",
            "-I", searchPaths.includeSearchPath.pathString,
            "-Xlinker", "-rpath",
            "-Xlinker", searchPaths.librarySearchPath.pathString,
        ]
        arguments.append(contentsOf: projectDescriptionFlags)

        var files: [String] = [manifestPath.pathString]
        files.append(contentsOf: manifestExtensions.map(\.pathString))

        if files.count > 1 {
            let cpuCount = ProcessInfo.processInfo.processorCount
            let threadsCount = min(files.count, cpuCount) + 1
            arguments.append(contentsOf: ["-j", "\(threadsCount)"])
        }

        let packageDescriptionArguments: [String] = try {
            if case .package = manifest {
                let manifestPath = try swiftPackageManagerController.getManifestAPIPath().pathString
                let packageVersion = try swiftPackageManagerController.getToolsVersion(
                    at: path.parentDirectory
                )
                return [
                    "-I", manifestPath,
                    "-L", manifestPath,
                    "-F", manifestPath,
                    "-lPackageDescription",
                    "-package-description-version", packageVersion.description,
                    "-D", "GEKO",
                    "-Xlinker", "-rpath",
                    "-Xlinker", manifestPath,
                ]
            } else {
                return []
            }
        }()

        arguments.append(contentsOf: projectDescriptionHelperArguments)
        arguments.append(contentsOf: packageDescriptionArguments)
        // arguments.append(manifestPath.pathString)
        // arguments.append(contentsOf: manifestExtensions.map(\.pathString))
        arguments.append(contentsOf: files)

        return arguments
    }

    private func loadDataForManifest(
        _ manifest: Manifest,
        at path: AbsolutePath,
        manifestExtensions: [AbsolutePath],
        hash: String
    ) throws -> Data {
        let compiledHashFolderPath = cacheDirectory.appending(component: hash)
        let compiledPath = compiledHashFolderPath.appending(component: manifest.name)

        let projectDescriptionHelpersCacheDirectory =
            try cacheDirectoryProviderFactory
            .cacheDirectories(config: nil)
            .cacheDirectory(for: .projectDescriptionHelpers)
        let helperArguments = try projectDescriptionHelpersArguments(
            manifest: manifest,
            at: path,
            cacheDirectory: projectDescriptionHelpersCacheDirectory
        )

        if !fileHandler.exists(compiledPath) {
            let timer = clock.startTimer()

            try compileManifest(
                manifest,
                at: path,
                manifestExtensions: manifestExtensions,
                to: compiledPath,
                projectDescriptionHelperArguments: helperArguments
            )

            let duration = timer.stop()
            let time = String(format: "%.3f", duration)
            logger.info("Built \(path) in (\(time)s)", metadata: .success)
        }

        try modifyAcceesDateForPath(path: compiledHashFolderPath)

        return try loadDataForCompiledManifest(manifest, at: compiledPath)
    }

    private func loadDataForCompiledManifest(
        _ manifest: Manifest,
        at path: AbsolutePath
    ) throws -> Data {
        let arguments: [String] = [
            path.pathString,
            "--geko-dump",
        ]

        let string = try system.capture(arguments, verbose: false, environment: system.env)

        guard let startTokenRange = string.range(of: CompiledManifestLoader.startManifestToken),
            let endTokenRange = string.range(of: CompiledManifestLoader.endManifestToken)
        else {
            return string.data(using: .utf8)!
        }

        let preManifestLogs = String(string[string.startIndex..<startTokenRange.lowerBound]).chomp()
        let postManifestLogs = String(string[endTokenRange.upperBound..<string.endIndex]).chomp()

        if !preManifestLogs.isEmpty { logger.info("\(path.pathString): \(preManifestLogs)") }
        if !postManifestLogs.isEmpty { logger.info("\(path.pathString):\(postManifestLogs)") }

        let manifest = string[startTokenRange.upperBound..<endTokenRange.lowerBound]

        return manifest.data(using: .utf8)!
    }

    private func compileManifest(
        _ manifest: Manifest,
        at path: AbsolutePath,
        manifestExtensions: [AbsolutePath],
        to destinationPath: AbsolutePath,
        projectDescriptionHelperArguments: [String]
    ) throws {
        var mainPath = path

        // if there are several .swift files fed to swiftc, one of them must be named main.swift
        // so we copy main manifest file to a temporary directory with name main.swift and use it instead
        var tmpDir: TemporaryDirectory?
        if !manifestExtensions.isEmpty {
            tmpDir = try .init(removeTreeOnDeinit: true)
            mainPath = tmpDir!.path.appending(component: "main.swift")
            try fileHandler.copy(from: path, to: mainPath)
        }

        let arguments = try buildArguments(
            manifest,
            at: path,
            manifestPath: mainPath,
            manifestExtensions: manifestExtensions,
            to: destinationPath,
            projectDescriptionHelperArguments: projectDescriptionHelperArguments
        )

        do {
            try fileHandler.createFolder(destinationPath.parentDirectory)

            _ = try system.capture(arguments, verbose: false, environment: ProcessInfo.processInfo.environment)
        } catch {
            logUnexpectedImportErrorIfNeeded(in: path, error: error, manifest: manifest)
            logPluginHelperBuildErrorIfNeeded(in: path, error: error, manifest: manifest)
            throw error
        }
    }

    private func loadManifest<T: Decodable>(
        _ manifest: Manifest,
        at path: AbsolutePath
    ) throws -> T {
        let manifestPath = try manifestPath(
            manifest,
            at: path
        )

        let manifestExtensions =
            try manifestFilesLocator
            .locateManifestExtensionFiles(for: manifest, at: manifestPath)

        let hash = try calculateHash(
            path: path,
            manifestExtensions: manifestExtensions,
            manifestPath: manifestPath,
            manifest: manifest
        )

        let data = try loadDataForManifest(manifest, at: manifestPath, manifestExtensions: manifestExtensions, hash: hash)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            guard let error = error as? DecodingError else {
                throw ManifestLoaderError.manifestLoadingFailed(
                    path: manifestPath,
                    data: data,
                    context: error.localizedDescription
                )
            }

            let json = (String(data: data, encoding: .utf8) ?? "nil")

            func pathDescription(for codingKeys: [any CodingKey]) -> String {
                var result = "'root"
                for key in codingKeys {
                    if let int = key.intValue {
                        result += "[\(int)]"
                    } else {
                        result += ".\(key.stringValue)"
                    }
                }
                result += "'"

                return result
            }

            switch error {
            case let .typeMismatch(type, context):
                throw ManifestLoaderError.manifestLoadingFailed(
                    path: manifestPath,
                    data: data,
                    context: """
                        The content of the manifest did not match the expected type of: \(String(describing: type).bold())
                        \(context.debugDescription)
                        """
                )
            case let .valueNotFound(value, _):
                throw ManifestLoaderError.manifestLoadingFailed(
                    path: manifestPath,
                    data: data,
                    context: """
                        Expected a non-optional value for property of type \(String(describing: value).bold()) but found a nil value.
                        \(json.bold())
                        """
                )
            case let .keyNotFound(codingKey, context):
                let path = pathDescription(for: context.codingPath + [codingKey])
                throw ManifestLoaderError.manifestLoadingFailed(
                    path: manifestPath,
                    data: data,
                    context: """
                        Did not find property with name \(codingKey.stringValue.bold()) at path \(path.bold()) in the JSON represented by:
                        \(json.bold())
                        """
                )
            case let .dataCorrupted(context):
                throw ManifestLoaderError.manifestLoadingFailed(
                    path: manifestPath,
                    data: data,
                    context: """
                        The encoded data for the manifest is corrupted.
                        \(context.debugDescription)
                        """
                )
            @unknown default:
                throw ManifestLoaderError.manifestLoadingFailed(
                    path: manifestPath,
                    data: data,
                    context: """
                        Unable to decode the manifest for an unknown reason.
                        \(error.localizedDescription)
                        """
                )
            }
        }
    }

    private func modifyAcceesDateForPath(path: AbsolutePath) throws {
        try fileHandler.fileUpdateAccessDate(path: path, date: clock.now)
    }

    // MARK: - Hashing

    private func calculateHash(
        path: AbsolutePath,
        manifestExtensions: [AbsolutePath],
        manifestPath: AbsolutePath,
        manifest: Manifest
    ) throws -> String {
        var hasher = MD5Hasher()
        try calculateManifestHash(at: manifestPath, manifestExtensions: manifestExtensions, hasher: &hasher)

        switch manifest {
        case .config, .plugin:
            // helpers cannot be used from Config.swift and Plugin.swift
            break
        case .project, .workspace, .dependencies, .package, .template:
            if let helpersHash = try calculateHelpersHash(at: path) {
                hasher.combine(helpersHash)
            }
        }

        if let pluginsHashCache {
            hasher.combine(pluginsHashCache)
        }
        hasher.combine(Constants.version)
        return hasher.finalize()
    }

    private func calculateManifestHash(at path: AbsolutePath, manifestExtensions: [AbsolutePath], hasher: inout MD5Hasher) throws {
        hasher.combine(path)
        try hasher.combine(fileHandler.readFile(path))
        for ext in manifestExtensions {
            hasher.combine(ext)
            try hasher.combine(fileHandler.readFile(ext))
        }
    }

    private func calculateHelpersHash(at path: AbsolutePath) throws -> String? {
        guard let helpersDirectory = helpersDirectoryLocator.locate(at: path) else {
            return nil
        }

        let hash = try projectDescriptionHelpersHasher.hash(helpersDirectory: helpersDirectory)

        return hash
    }

    private func calculatePluginsHash(for plugins: Plugins) throws -> String? {
        try plugins.projectDescriptionHelpers
            .map { try projectDescriptionHelpersHasher.hash(helpersDirectory: $0.path) }
            .joined(separator: "-")
            .md5
    }

    // MARK: - Logging

    private func logUnexpectedImportErrorIfNeeded(in path: AbsolutePath, error: Error, manifest: Manifest) {
        guard case let GekoSupport.SystemError.terminated(command, _, standardError, _) = error,
            manifest == .config || manifest == .plugin,
            command == "swiftc",
            let errorMessage = String(data: standardError, encoding: .utf8)
        else { return }

        let defaultHelpersName = ProjectDescriptionHelpersBuilder.defaultHelpersName

        if errorMessage.contains(defaultHelpersName) {
            logger.error("Cannot import \(defaultHelpersName) in \(manifest.fileName(path))")
            logger.info("Project description helpers that depend on plugins are not allowed in \(manifest.fileName(path))")
        } else if errorMessage.contains("import") {
            logger.error("Helper plugins are not allowed in \(manifest.fileName(path))")
        }
    }

    private func logPluginHelperBuildErrorIfNeeded(in _: AbsolutePath, error: Error, manifest _: Manifest) {
        guard case let GekoSupport.SystemError.terminated(command, _, standardError, _) = error,
            command == "swiftc",
            let errorMessage = String(data: standardError, encoding: .utf8)
        else { return }

        let pluginHelpers = plugins.projectDescriptionHelpers
        guard let pluginHelper = pluginHelpers.first(where: { errorMessage.contains($0.name) }) else { return }

        logger.error("Unable to build plugin \(pluginHelper.name) located at \(pluginHelper.path)")
    }
}
