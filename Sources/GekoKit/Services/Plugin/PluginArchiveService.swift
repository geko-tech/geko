import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoDependencies
import GekoLoader
import GekoSupport
import GekoPlugin
import GekoAutomation
import GekoCore

enum GekoPluginArchiveError: FatalError, Equatable {
    case executableNotFound(name: String)
    case mapperNotFound(name: String)
    case projectDescriptionBranchNotFound(path: String)
    case packageResolvedNotFound(path: String)
    case unknownArch(name: String)

    var description: String {
        switch self {
        case let .executableNotFound(name):
            "Executable \(name) was not found in Package.swift"
        case let .mapperNotFound(name):
            "Mapper \(name) was not found in Package.swift"
        case let .projectDescriptionBranchNotFound(path):
            "Couldn't get a branch with the ProjectDescription version for \(path)."
        case let .packageResolvedNotFound(path):
            "Couldn't find Package.resolved in \(path) path."
        case let .unknownArch(name):
            "Unknown machine architecture: \(name)"
        }
    }

    var type: ErrorType {
        switch self {
        case .executableNotFound, .mapperNotFound, .projectDescriptionBranchNotFound, .packageResolvedNotFound, .unknownArch:
                .abort
        }
    }
}

final class PluginArchiveService {
    private let swiftPackageManagerController: SwiftPackageManagerControlling
    private let xcodebuildController: XcodeBuildControlling
    private let manifestLoader: ManifestLoading
    private let fileArchiverFactory: FileArchivingFactorying
    private let projectDescriptionBranchVersionParser: ProjectDescriptionBranchVersionParser
    private let jsonEncoder: JSONEncoder = {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        return jsonEncoder
    }()

    init(
        swiftPackageManagerController: SwiftPackageManagerControlling = SwiftPackageManagerController(),
        xcodebuildController: XcodeBuildControlling = XcodeBuildController(),
        manifestLoader: ManifestLoading = CompiledManifestLoader(),
        fileArchiverFactory: FileArchivingFactorying = FileArchivingFactory(),
        projectDescriptionBranchVersionParser: ProjectDescriptionBranchVersionParser = ProjectDescriptionBranchVersionParser()
    ) {
        self.swiftPackageManagerController = swiftPackageManagerController
        self.xcodebuildController = xcodebuildController
        self.manifestLoader = manifestLoader
        self.fileArchiverFactory = fileArchiverFactory
        self.projectDescriptionBranchVersionParser = projectDescriptionBranchVersionParser
    }

    func run(
        path: String?,
        outputPath: String?,
        configuration: PluginCommand.PackageConfiguration,
        createZip: Bool
    ) throws {
        let path = try self.path(path)
        let outputPath =  try outputPath.map { try self.path($0) }
        let plugin = try manifestLoader.loadPlugin(at: path)

        let executablesPackageProducts = try packageProducts(at: path, type: .executable)

        let pluginTaskProducts = try plugin.executables.map { executable in
            guard let execubleName = executablesPackageProducts.first(where: { $0 == executable.name }) else {
                throw GekoPluginArchiveError.executableNotFound(name: executable.name)
            }
            return execubleName
        }

        let libraryPackageProducts = try packageProducts(at: path, type: .library(.dynamic))

        let workspaceMapperName = try plugin.workspaceMapper.map { workspaceMapper in
            guard libraryPackageProducts.contains(where: { $0 == workspaceMapper.name }) else {
                throw GekoPluginArchiveError.mapperNotFound(name: workspaceMapper.name)
            }
            return workspaceMapper.name
        }

        try FileHandler.shared.inTemporaryDirectory { temporaryDirectory in
            try archiveProducts(
                taskProducts: pluginTaskProducts,
                workspaceMapperName: workspaceMapperName,
                path: path,
                outputPath: outputPath,
                plugin: plugin,
                createZip: createZip,
                configuration: configuration,
                in: temporaryDirectory
            )
        }
    }

    // MARK: - Helpers

    private func packageProducts(at path: AbsolutePath, type: PackageInfo.Product.ProductType) throws -> [String] {
        guard packagePath(path: path) != nil else { return [] }

        let packageInfo = try swiftPackageManagerController.loadPackageInfo(at: path)
        return packageInfo.products
            .filter {
                $0.type == type
            }
            .map(\.name)
    }

    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath)
        } else {
            return FileHandler.shared.currentPath
        }
    }

    private func archiveProducts(
        taskProducts: [String],
        workspaceMapperName: String?,
        path: AbsolutePath,
        outputPath: AbsolutePath?,
        plugin: ProjectDescription.Plugin,
        createZip: Bool,
        configuration: PluginCommand.PackageConfiguration,
        in temporaryDirectory: AbsolutePath
    ) throws {
        let artifactsPath = temporaryDirectory.appending(component: "artifacts")
        let buildPath = temporaryDirectory.appending(component: "build")

        #if os(Linux)
        var archStr: String?
        if case let .linux(arch: arch) = PluginOS.current {
            archStr = arch
        }
        guard let arch = PluginBinaryArch(rawValue: archStr!) else {
            throw GekoPluginArchiveError.unknownArch(name: archStr!)
        }
        #endif

        for product in taskProducts {
            logger.notice("Building \(product)...")
#if os(macOS)
            try swiftPackageManagerController.buildFatReleaseBinary(
                packagePath: path,
                product: product,
                buildPath: buildPath,
                outputPath: artifactsPath
            )
#else
            try swiftPackageManagerController.buildReleaseBinary(
                for: arch,
                packagePath: path,
                product: product,
                buildPath: buildPath,
                outputPath: artifactsPath
            )
#endif
        }
        let executablesPath = artifactsPath.appending(component: Constants.Plugins.executables)
        try FileHandler.shared.createFolder(executablesPath)

        for taskProduct in taskProducts {
            try FileHandler.shared.copy(from: artifactsPath.appending(component: taskProduct),
                                        to: executablesPath.appending(component: taskProduct))
            let resourceBundleName = "\(plugin.name)_\(taskProduct).bundle"
            let resourceBundlePath = buildPath.appending(component: configuration.rawValue).appending(component: resourceBundleName)
            if FileHandler.shared.exists(resourceBundlePath) {
                try FileHandler.shared.copy(from: resourceBundlePath, to: executablesPath.appending(component: resourceBundleName))
            }
        }

        let workspaceMapperPaths = try buildWorkspaceMapper(
            workspaceMapperName: workspaceMapperName,
            configuration: configuration,
            path: path,
            temporaryDirectory: temporaryDirectory,
            artifactsPath: artifactsPath
        )

        var paths: [AbsolutePath] = [path.appending(component: "Plugin.swift")]

        let helpersPath = path.appending(component: Constants.helpersDirectoryName)
        if FileHandler.shared.exists(helpersPath) {
            paths.append(helpersPath)
        }
        let templatesPath = path.appending(component: Constants.templatesDirectoryName)
        if FileHandler.shared.exists(templatesPath) {
            paths.append(templatesPath)
        }
        if !taskProducts.isEmpty {
            paths.append(executablesPath)
        }
        paths.append(contentsOf: workspaceMapperPaths)

        let outputPath = createOutputPath(path: path, outputPath: outputPath, createZip: createZip)

        if createZip {
            try createArchive(at: outputPath, paths: paths, plugin: plugin)
        } else {
            try createPluginBuildFolder(at: outputPath, paths: paths)
        }
    }

    private func createOutputPath(path: AbsolutePath, outputPath: AbsolutePath?, createZip: Bool) -> AbsolutePath {
        if createZip {
            return outputPath.map { $0 } ?? path
        } else {
            return outputPath.map { $0 } ?? path.appending(component: "PluginBuild")
        }
    }

    private func createArchive(at path: AbsolutePath, paths: [AbsolutePath], plugin: ProjectDescription.Plugin) throws {
        let archiver = try fileArchiverFactory.makeFileArchiver(
            for: paths
        )
        let archStr: String
        let osStr: String
        switch PluginOS.current {
        case let .linux(arch: arch):
            archStr = ".\(arch)"
            osStr = "linux"
        case .macos:
            archStr = ""
            osStr = "macos"
        }
        let zipName = "\(plugin.name).\(osStr)\(archStr).geko-plugin.zip"
        let temporaryZipPath = try archiver.zip(name: zipName)
        let zipPath = path.appending(component: zipName)
        if FileHandler.shared.exists(zipPath) {
            try FileHandler.shared.delete(zipPath)
        }
        if !FileHandler.shared.exists(path) {
            try FileHandler.shared.createFolder(path)
        }
        try FileHandler.shared.copy(
            from: temporaryZipPath,
            to: zipPath
        )
        try archiver.delete()

        logger.notice(
            "Plugin was successfully archived. Create a new Github release and attach the file \(zipPath.pathString) as an artifact.",
            metadata: .success
        )
    }

    private func buildWorkspaceMapper(
        workspaceMapperName: String?,
        configuration: PluginCommand.PackageConfiguration,
        path: AbsolutePath,
        temporaryDirectory: AbsolutePath,
        artifactsPath: AbsolutePath
    ) throws -> [AbsolutePath] {
        guard let workspaceMapperName else { return [] }

        logger.notice("Building \(workspaceMapperName)...")
        let derivedDataPath = temporaryDirectory.appending(component: "DerivedData")
#if os(macOS)
        try buildFramework(
            scheme: workspaceMapperName,
            path: path,
            derivedDataPath: derivedDataPath,
            configuration: configuration,
            outputPath: artifactsPath
        )
#else
        try buildLibrary(
            product: workspaceMapperName,
            path: path,
            buildPath: derivedDataPath,
            configuration: configuration,
            outputPath: artifactsPath
        )
#endif

        let mappersPath = artifactsPath.appending(component: Constants.Plugins.mappers)
        try FileHandler.shared.createFolder(mappersPath)
        let pluginInfoPath = artifactsPath.appending(component: Constants.Plugins.infoFileName)

#if os(macOS)
        try FileHandler.shared.copy(from: artifactsPath.appending(component: "\(workspaceMapperName).framework"),
                                    to: mappersPath.appending(component: "\(workspaceMapperName).framework"))
#else
        try FileHandler.shared.copy(
            from: artifactsPath.appending(component: "lib\(workspaceMapperName).so"),
            to: mappersPath.appending(component: "lib\(workspaceMapperName).so")
        )
#endif

        guard let packageResolvedPath = packageResolvedPath(path: path) else {
            throw GekoPluginArchiveError.packageResolvedNotFound(path: path.pathString)
        }

        let projectDescriptionVersion = try projectDescriptionVersion(packageResolvedPath: packageResolvedPath)
        let pluginInfo = PluginInfo(projectDescriptionVersion: projectDescriptionVersion)
        try savePluginInfo(pluginInfo: pluginInfo, pluginInfoPath: pluginInfoPath)

        return [mappersPath, pluginInfoPath]
    }

#if os(Linux)
    private func buildLibrary(
        product: String,
        path: AbsolutePath,
        buildPath: AbsolutePath,
        configuration: PluginCommand.PackageConfiguration,
        outputPath: AbsolutePath
    ) throws {
        var archStr: String?
        if case let .linux(arch: arch) = PluginOS.current {
            archStr = arch
        }
        guard let arch = PluginBinaryArch(rawValue: archStr!) else {
            throw GekoPluginArchiveError.unknownArch(name: archStr!)
        }
        try swiftPackageManagerController.buildLibrary(
            for: arch,
            packagePath: path,
            product: product,
            configuration: configuration.rawValue,
            isDynamic: true,
            buildPath: buildPath,
            outputPath: outputPath
        )
    }
#endif

    private func buildFramework(
        scheme: String,
        path: AbsolutePath,
        derivedDataPath: AbsolutePath,
        configuration: PluginCommand.PackageConfiguration,
        outputPath: AbsolutePath
    ) throws {
        try xcodebuildController.build(
            .workspace(path),
            scheme: scheme,
            destination: nil,
            rosetta: false,
            derivedDataPath: derivedDataPath,
            clean: true,
            arguments: [
                .configuration(configuration.xcodebuildConfiguration),
                .destination("generic/platform=macOS")
            ]
        )

        let componentsToBuild = ["Build", "Products", configuration.xcodebuildConfiguration]
        let componentsToFramework = componentsToBuild + ["PackageFrameworks", "\(scheme).framework"]
        try FileHandler.shared.copy(
            from: derivedDataPath.appending(components: componentsToFramework),
            to: outputPath.appending(component: "\(scheme).framework")
        )
        let resourceBundleName = "\(path.basenameWithoutExt)_\(scheme).bundle"
        let resourceBundlePath = derivedDataPath.appending(components: componentsToBuild).appending(component: resourceBundleName)
        if FileHandler.shared.exists(resourceBundlePath) {
            try FileHandler.shared.copy(from: resourceBundlePath, to: outputPath.appending(component: "\(scheme).framework").appending(component: resourceBundleName))
        }
    }

    private func packagePath(path: AbsolutePath) -> AbsolutePath? {
        let packagePath = path.appending(component: "Package.swift")
        guard FileHandler.shared.exists(packagePath) else {
            return nil
        }
        return packagePath
    }

    private func packageResolvedPath(path: AbsolutePath) -> AbsolutePath? {
        let packagePath = path.appending(component: "Package.resolved")
        guard FileHandler.shared.exists(packagePath) else {
            return nil
        }
        return packagePath
    }

    private func savePluginInfo(pluginInfo: PluginInfo, pluginInfoPath: AbsolutePath) throws {
        let jsonData = try jsonEncoder.encode(pluginInfo)
        if let content = String(data: jsonData, encoding: .utf8) {
            try FileHandler.shared.write(content, path: pluginInfoPath, atomically: true)
        }
    }

    private func createPluginBuildFolder(at path: AbsolutePath, paths: [AbsolutePath]) throws {

        if !FileHandler.shared.exists(path) {
            try FileHandler.shared.createFolder(path)
        }
        for srcPath in paths {
            let destPath = path.appending(component: srcPath.basename)
            // e.g. Plugin.swift from the Plugin directory, so there is no point to copy or replace it
            if srcPath == destPath {
                continue
            }
            // Previously built artifact
            if FileHandler.shared.exists(destPath) {
                try FileHandler.shared.delete(destPath)
            }
            try FileHandler.shared.copy(from: srcPath, to: destPath)
        }
        logger.notice(
            "Plugin was successfully archived and saved at \(path)",
            metadata: .success
        )
    }

    private func projectDescriptionVersion(packageResolvedPath: AbsolutePath) throws -> String {
        let extractedVersion = try projectDescriptionBranchVersionParser.parse(packageResolvedPath: packageResolvedPath)

        if let extractedVersion {
            return extractedVersion
        } else {
            #if DEBUG
            return Constants.projectDescriptionVersion
            #else
            throw GekoPluginArchiveError.projectDescriptionBranchNotFound(path: packageResolvedPath.pathString)
            #endif
        }
    }
}

private extension PluginCommand.PackageConfiguration {
    var xcodebuildConfiguration: String {
        switch self {
        case .debug:
            "Debug"
        case .release:
            "Release"
        }
    }
}
