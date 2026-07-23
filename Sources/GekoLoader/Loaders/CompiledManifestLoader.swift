import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

private struct ManifestObjectInput {
    let manifest: Manifest
    let path: AbsolutePath
    let extensions: [AbsolutePath]
    let hash: String
    let identifier: String
    let entryPoint: String
    let objectPath: AbsolutePath
    let buildArguments: [String]
}

private struct ManifestObject {
    let manifest: Manifest
    let path: AbsolutePath
    let hash: String
    let identifier: String
    let entryPoint: String
    let objectPath: AbsolutePath
    let linkArguments: [String]
}

public class CompiledManifestLoader: ManifestLoading {

    // MARK: Static

    static let startManifestToken = "GEKO_MANIFEST_START"
    static let endManifestToken = "GEKO_MANIFEST_END"
    static let batchStartManifestToken = "GEKO_BATCH_MANIFEST_START"
    static let batchEndManifestToken = "GEKO_BATCH_MANIFEST_END"
    private static let manifestObjectCacheVersion = "manifest-object-v1"
    private static let manifestRunnerCacheVersion = "manifest-runner-v1"

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

    public func loadProjects(at paths: [AbsolutePath]) throws -> [AbsolutePath: ProjectDescription.Project] {
        let timer = clock.startTimer()
        let manifestObjects = try prepareManifestObjects(.project, at: paths.sorted())
        let groups = Dictionary(grouping: manifestObjects) {
            $0.linkArguments.joined(separator: "\u{0}")
        }

        var projects: [AbsolutePath: ProjectDescription.Project] = [:]
        for group in groups.values {
            let dataByIdentifier = try loadDataForManifestObjects(group)
            for manifestObject in group {
                guard let data = dataByIdentifier[manifestObject.identifier] else {
                    throw ManifestLoaderError.unexpectedOutput(manifestObject.path)
                }
                projects[manifestObject.path.parentDirectory] = try decodeManifest(
                    ProjectDescription.Project.self,
                    manifestPath: manifestObject.path,
                    data: data
                )
            }
        }
        logLoadedManifestCount(projects.count, duration: timer.stop())
        return projects
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
        builder: ProjectDescriptionHelpersBuilding
    ) throws -> [String] {
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
            let args: [String] = try builder.build(
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

    private func manifestBuildArguments(
        _ manifest: Manifest,
        at path: AbsolutePath,
        projectDescriptionHelperArguments: [String]
    ) throws -> [String] {
        let projectDescriptionPath = try resourceLocator.projectDescription()
        let searchPaths = ProjectDescriptionSearchPaths.paths(for: projectDescriptionPath)

        let projectDescriptionFlags: [String]
        if projectDescriptionPath.extension == "dylib" || projectDescriptionPath.extension == "so" {
            projectDescriptionFlags = [
                "-L", searchPaths.librarySearchPath.pathString,
                "-lProjectDescription",
            ]
        } else {
            projectDescriptionFlags = [
                "-F", searchPaths.frameworkSearchPath.pathString,
                "-framework", "ProjectDescription",
            ]
        }

        var arguments = [
            "-I", searchPaths.includeSearchPath.pathString,
            "-Xlinker", "-rpath",
            "-Xlinker", searchPaths.librarySearchPath.pathString,
        ]
        arguments.append(contentsOf: projectDescriptionFlags)

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

        return arguments
    }

    private func prepareManifestObjects(
        _ manifest: Manifest,
        at paths: [AbsolutePath]
    ) throws -> [ManifestObject] {
        let helpersCacheDirectory =
            try cacheDirectoryProviderFactory
            .cacheDirectories(config: nil)
            .cacheDirectory(for: .projectDescriptionHelpers)
        let helpersBuilder = projectDescriptionHelpersBuilderFactory.projectDescriptionHelpersBuilder(
            cacheDirectory: helpersCacheDirectory
        )

        let inputs = try paths.map { path -> ManifestObjectInput in
            let sourcePath = try manifestPath(manifest, at: path)
            let manifestExtensions =
                try manifestFilesLocator
                .locateManifestExtensionFiles(for: manifest, at: sourcePath)
                .sorted()
            let contentHash = try calculateHash(
                path: path,
                manifestExtensions: manifestExtensions,
                manifestPath: sourcePath,
                manifest: manifest
            )
            let helperArguments = try projectDescriptionHelpersArguments(
                manifest: manifest,
                at: sourcePath,
                builder: helpersBuilder
            )
            let buildArguments = try manifestBuildArguments(
                manifest,
                at: sourcePath,
                projectDescriptionHelperArguments: helperArguments
            )
            var objectHasher = MD5Hasher()
            objectHasher.combine(contentHash)
            for argument in buildArguments {
                objectHasher.combine(argument)
            }
            let hash = objectHasher.finalize()
            let identifier = hash
            let entryPoint = "geko_manifest_\(hash)"
            let objectFolder = cacheDirectory.appending(component: hash)
            let objectPath = objectFolder.appending(component: "\(manifest.name).o")
            return ManifestObjectInput(
                manifest: manifest,
                path: sourcePath,
                extensions: manifestExtensions,
                hash: hash,
                identifier: identifier,
                entryPoint: entryPoint,
                objectPath: objectPath,
                buildArguments: buildArguments
            )
        }

        return try inputs.map(context: ExecutionContext.concurrent) {
            try compileManifestObject($0)
        }
    }

    private func compileManifestObject(_ input: ManifestObjectInput) throws -> ManifestObject {
        if !fileHandler.exists(input.objectPath) {
            let temporaryDirectory = try TemporaryDirectory(removeTreeOnDeinit: true)
            let sourcePath = temporaryDirectory.path.appending(component: "main.swift")
            try combinedManifestSource(
                manifestPath: input.path,
                extensions: input.extensions
            ).data(using: .utf8)!.write(to: sourcePath.url, options: .atomic)

            try fileHandler.createFolder(input.objectPath.parentDirectory)
            let temporaryObjectPath = input.objectPath.parentDirectory.appending(
                component: ".\(input.objectPath.basename).\(UUID().uuidString).tmp"
            )
            var arguments = swiftCompilerPrefix()
            arguments += [
                "swiftc",
                "-c",
                "-Onone",
                "-suppress-warnings",
                "-module-name", "GekoManifest_\(input.hash)",
                "-Xfrontend", "-entry-point-function-name",
                "-Xfrontend", input.entryPoint,
            ]
            arguments.append(contentsOf: input.buildArguments)
            arguments.append(contentsOf: [
                sourcePath.pathString,
                "-o", temporaryObjectPath.pathString,
            ])

            do {
                _ = try system.capture(
                    arguments,
                    verbose: false,
                    environment: ProcessInfo.processInfo.environment
                )
                if fileHandler.exists(input.objectPath) {
                    try fileHandler.delete(temporaryObjectPath)
                } else {
                    try fileHandler.move(from: temporaryObjectPath, to: input.objectPath)
                }
            } catch {
                try? fileHandler.delete(temporaryObjectPath)
                if !fileHandler.exists(input.objectPath) {
                    logUnexpectedImportErrorIfNeeded(in: input.path, error: error, manifest: input.manifest)
                    logPluginHelperBuildErrorIfNeeded(in: input.path, error: error, manifest: input.manifest)
                    throw error
                }
            }
        }

        try modifyAcceesDateForPath(path: input.objectPath.parentDirectory)
        return ManifestObject(
            manifest: input.manifest,
            path: input.path,
            hash: input.hash,
            identifier: input.identifier,
            entryPoint: input.entryPoint,
            objectPath: input.objectPath,
            linkArguments: input.buildArguments
        )
    }

    private func combinedManifestSource(
        manifestPath: AbsolutePath,
        extensions: [AbsolutePath]
    ) throws -> String {
        try (extensions + [manifestPath]).map { sourcePath in
            let escapedPath = sourcePath.pathString
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return """
            #sourceLocation(file: "\(escapedPath)", line: 1)
            \(try fileHandler.readTextFile(sourcePath))
            #sourceLocation()
            """
        }.joined(separator: "\n")
    }

    private func loadDataForManifestObjects(
        _ manifestObjects: [ManifestObject]
    ) throws -> [String: Data] {
        let orderedObjects = manifestObjects.sorted { $0.path < $1.path }
        let runnerPath = try buildManifestRunner(for: orderedObjects)
        let output: String
        do {
            output = try system.capture(
                [runnerPath.pathString, "--geko-dump"],
                verbose: false,
                environment: system.env
            )
        } catch {
            let standardOutput: Data?
            switch error {
            case let SystemError.terminated(_, _, _, output),
                let SystemError.signalled(_, _, _, output):
                standardOutput = output
            default:
                standardOutput = nil
            }
            if
                let standardOutput,
                let output = String(data: standardOutput, encoding: .utf8),
                let failedManifest = lastStartedManifest(in: output, manifestObjects: orderedObjects)
            {
                throw ManifestLoaderError.manifestLoadingFailed(
                    path: failedManifest.path,
                    data: standardOutput,
                    context: "The manifest batch runner failed while loading this manifest.\n\(error)"
                )
            }
            throw error
        }
        try modifyAcceesDateForPath(path: runnerPath.parentDirectory)

        var dataByIdentifier: [String: Data] = [:]
        var remainingOutput = output[...]
        for manifestObject in orderedObjects {
            let startMarker = "\(Self.batchStartManifestToken) \(manifestObject.identifier)"
            let endMarker = "\(Self.batchEndManifestToken) \(manifestObject.identifier) 0"
            guard
                let startRange = remainingOutput.range(of: startMarker),
                let endRange = remainingOutput.range(
                    of: endMarker,
                    range: startRange.upperBound..<remainingOutput.endIndex
                )
            else {
                throw ManifestLoaderError.unexpectedOutput(manifestObject.path)
            }

            let manifestOutput = String(remainingOutput[startRange.upperBound..<endRange.lowerBound])
            dataByIdentifier[manifestObject.identifier] = parseManifestOutput(
                manifestOutput,
                path: manifestObject.path
            )
            remainingOutput = remainingOutput[endRange.upperBound...]
        }
        return dataByIdentifier
    }

    private func lastStartedManifest(
        in output: String,
        manifestObjects: [ManifestObject]
    ) -> ManifestObject? {
        let lastStartLine = output
            .split(separator: "\n")
            .last { $0.hasPrefix(Self.batchStartManifestToken) }
        guard let identifier = lastStartLine?.split(separator: " ").last else {
            return nil
        }
        return manifestObjects.first { $0.identifier == identifier }
    }

    private func buildManifestRunner(
        for manifestObjects: [ManifestObject]
    ) throws -> AbsolutePath {
        var hasher = MD5Hasher()
        hasher.combine(Self.manifestRunnerCacheVersion)
        hasher.combine(try system.swiftlangVersion())
        hasher.combine(Constants.version)
        for manifestObject in manifestObjects {
            hasher.combine(manifestObject.identifier)
            hasher.combine(manifestObject.hash)
            for argument in manifestObject.linkArguments {
                hasher.combine(argument)
            }
        }
        let runnerHash = hasher.finalize()
        let runnerFolder = cacheDirectory.appending(component: runnerHash)
        let runnerPath = runnerFolder.appending(component: "runner")

        guard !fileHandler.exists(runnerPath) else {
            return runnerPath
        }

        let temporaryDirectory = try TemporaryDirectory(removeTreeOnDeinit: true)
        let runnerSourcePath = temporaryDirectory.path.appending(component: "main.swift")
        try manifestRunnerSource(for: manifestObjects)
            .data(using: .utf8)!
            .write(to: runnerSourcePath.url, options: .atomic)
        try fileHandler.createFolder(runnerFolder)
        let temporaryRunnerPath = runnerFolder.appending(
            component: ".runner.\(UUID().uuidString).tmp"
        )

        var arguments = swiftCompilerPrefix()
        arguments += [
            "swiftc",
            "-Onone",
            "-suppress-warnings",
            "-module-name", "GekoManifestRunner_\(runnerHash)",
        ]
        arguments.append(runnerSourcePath.pathString)
        arguments.append(contentsOf: manifestObjects.map(\.objectPath.pathString))
        if let linkArguments = manifestObjects.first?.linkArguments {
            arguments.append(contentsOf: linkArguments)
        }
        arguments.append(contentsOf: ["-o", temporaryRunnerPath.pathString])

        do {
            _ = try system.capture(
                arguments,
                verbose: false,
                environment: ProcessInfo.processInfo.environment
            )
            if fileHandler.exists(runnerPath) {
                try fileHandler.delete(temporaryRunnerPath)
            } else {
                try fileHandler.move(from: temporaryRunnerPath, to: runnerPath)
            }
        } catch {
            try? fileHandler.delete(temporaryRunnerPath)
            if !fileHandler.exists(runnerPath) {
                throw error
            }
        }
        return runnerPath
    }

    private func manifestRunnerSource(for manifestObjects: [ManifestObject]) -> String {
        let declarations = manifestObjects.enumerated().map { index, manifestObject in
            """
            @_silgen_name("\(manifestObject.entryPoint)")
            func manifest\(index)() -> Int32
            """
        }.joined(separator: "\n\n")
        let entries = manifestObjects.enumerated().map { index, manifestObject in
            "(\"\(manifestObject.identifier)\", manifest\(index))"
        }.joined(separator: ",\n    ")

        return """
        #if canImport(Darwin)
        import Darwin
        #else
        import Glibc
        #endif

        \(declarations)

        let manifests: [(String, () -> Int32)] = [
            \(entries)
        ]

        for (identifier, run) in manifests {
            print("\(Self.batchStartManifestToken) \\(identifier)")
            fflush(stdout)
            let result = run()
            print("\(Self.batchEndManifestToken) \\(identifier) \\(result)")
            fflush(stdout)
            if result != 0 {
                exit(result)
            }
        }
        """
    }

    private func parseManifestOutput(_ output: String, path: AbsolutePath) -> Data {
        guard
            let startTokenRange = output.range(of: Self.startManifestToken),
            let endTokenRange = output.range(
                of: Self.endManifestToken,
                range: startTokenRange.upperBound..<output.endIndex
            )
        else {
            return output.chomp().data(using: .utf8)!
        }

        let preManifestLogs = String(output[output.startIndex..<startTokenRange.lowerBound]).chomp()
        let postManifestLogs = String(output[endTokenRange.upperBound..<output.endIndex]).chomp()
        if !preManifestLogs.isEmpty { logger.info("\(path.pathString): \(preManifestLogs)") }
        if !postManifestLogs.isEmpty { logger.info("\(path.pathString):\(postManifestLogs)") }

        return String(output[startTokenRange.upperBound..<endTokenRange.lowerBound])
            .chomp()
            .data(using: .utf8)!
    }

    private func loadManifest<T: Decodable>(
        _ manifest: Manifest,
        at path: AbsolutePath
    ) throws -> T {
        let timer = clock.startTimer()
        guard let manifestObject = try prepareManifestObjects(manifest, at: [path]).first else {
            throw ManifestLoaderError.manifestNotFound(manifest, path)
        }
        let dataByIdentifier = try loadDataForManifestObjects([manifestObject])
        guard let data = dataByIdentifier[manifestObject.identifier] else {
            throw ManifestLoaderError.unexpectedOutput(manifestObject.path)
        }
        let result = try decodeManifest(T.self, manifestPath: manifestObject.path, data: data)
        let time = String(format: "%.3f", timer.stop())
        logger.info("Loaded \(manifestObject.path.pathString) in (\(time)s)", metadata: .success)
        return result
    }

    private func logLoadedManifestCount(_ count: Int, duration: TimeInterval) {
        let time = String(format: "%.3f", duration)
        logger.info("Loaded \(count) manifests in (\(time)s)", metadata: .success)
    }

    private func swiftCompilerPrefix() -> [String] {
#if os(macOS)
        ["/usr/bin/xcrun"]
#else
        []
#endif
    }

    private func decodeManifest<T: Decodable>(
        _ type: T.Type,
        manifestPath: AbsolutePath,
        data: Data
    ) throws -> T {
        do {
            return try decoder.decode(type, from: data)
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
        hasher.combine(manifest.name)
        hasher.combine(Self.manifestObjectCacheVersion)
        hasher.combine(try system.swiftlangVersion())
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
