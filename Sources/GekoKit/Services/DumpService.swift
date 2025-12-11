import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoLoader
import GekoPlugin
import GekoSupport

final class DumpService {
    private let manifestLoader: ManifestLoading
    private let fileHandler: FileHandling

    init(
        manifestLoader: ManifestLoading = CompiledManifestLoader(),
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.manifestLoader = manifestLoader
        self.fileHandler = fileHandler
    }

    func run(path: String?, manifest: DumpableManifest, resultFile: String?) async throws {
        let projectPath: AbsolutePath
        if let path {
            projectPath = try AbsolutePath(validating: path, relativeTo: AbsolutePath.current)
        } else {
            projectPath = AbsolutePath.current
        }

        let manifestGraphLoader = ManifestGraphLoader(
            manifestLoader: manifestLoader,
            workspaceMapper: SequentialWorkspaceMapper(mappers: []),
            graphMapper: SequentialGraphMapper([])
        )
        try await manifestGraphLoader.loadPlugins(at: projectPath)

        let encoded: Encodable
        switch manifest {
        case .project:
            encoded = try manifestLoader.loadProject(at: projectPath)
        case .workspace:
            encoded = try manifestLoader.loadWorkspace(at: projectPath)
        case .config:
            let configPath = projectPath.appending(component: Constants.gekoDirectoryName)
            let configFileName = Manifest.config.fileName(configPath)
            let configFilePath = configPath.appending(component: configFileName)

            var config = try manifestLoader.loadConfig(at: configPath)
            // TODO: File paths in config are resolved relatively to
            // manifest file itself, not manifest directory.
            // Need to review.
            try config.resolvePaths(generatorPaths: .init(manifestDirectory: configFilePath))

            encoded = config
        case .template:
            encoded = try manifestLoader.loadTemplate(at: projectPath)
        case .dependencies:
            encoded = try manifestLoader.loadDependencies(at: projectPath)
        case .plugin:
             encoded = try manifestLoader.loadPlugin(at: projectPath)
        }
        
        let json: JSON = try encoded.toJSON()
        let resultContent = json.toString(prettyPrint: true)
        if let resultFile = resultFile {
            let resultPath = try AbsolutePath(validating: resultFile, relativeTo: AbsolutePath.current)
            try fileHandler.write(resultContent, path: resultPath, atomically: true)
        } else {
            logger.notice("\(resultContent)")
        }
    }
}

enum DumpableManifest: String, CaseIterable {
    case project
    case workspace
    case config
    case template
    case dependencies
    case plugin
}
