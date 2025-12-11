import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGenerator
import GekoGraph
import GekoLoader
import GekoPlugin
import GekoSupport

enum EditServiceError: FatalError {
    case xcodeNotSelected

    var description: String {
        switch self {
        case .xcodeNotSelected:
            return "Couldn't determine the Xcode version to open the project. Make sure your Xcode installation is selected with 'xcode-select -s'."
        }
    }

    var type: ErrorType {
        switch self {
        case .xcodeNotSelected:
            return .abort
        }
    }
}

final class EditService {
    private let projectEditor: ProjectEditing
    private let opener: Opening
    private let configLoader: ConfigLoading
    private let pluginsFacade: PluginsFacading
    private let fileHandler: FileHandling

    private static var temporaryDirectory: AbsolutePath?

    init(
        projectEditor: ProjectEditing = ProjectEditor(),
        opener: Opening = Opener(),
        configLoader: ConfigLoading = ConfigLoader(manifestLoader: CompiledManifestLoader()),
        pluginsFacade: PluginsFacading = PluginsFacade(),
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.projectEditor = projectEditor
        self.opener = opener
        self.configLoader = configLoader
        self.pluginsFacade = pluginsFacade
        self.fileHandler = fileHandler
    }

    func run(
        path: String?,
        noOpen: Bool,
        onlyCurrentDirectory: Bool
    ) async throws {
        let path = try self.path(path)
        let plugins = await loadPlugins(at: path)

        let tmpDir = path.appending(components: [".geko", "GekoProject"])
        if !fileHandler.exists(tmpDir) {
            try fileHandler.createFolder(tmpDir)
        }
        let workspacePath = try projectEditor.edit(
            at: path,
            in: tmpDir,
            onlyCurrentDirectory: onlyCurrentDirectory,
            plugins: plugins
        )
        if !noOpen {
            guard let selectedXcode = try XcodeController.shared.selected() else {
                throw EditServiceError.xcodeNotSelected
            }
            try opener.open(path: workspacePath, application: selectedXcode.path, wait: false)
        }
    }

    // MARK: - Helpers

    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath)
        } else {
            return FileHandler.shared.currentPath
        }
    }

    private func loadPlugins(at path: AbsolutePath) async -> Plugins {
        guard let config = try? configLoader.loadConfig(path: path) else {
            logger.warning("Unable to load Config.swift, fix any compiler errors and re-run for plugins to be loaded.")
            return .none
        }

        guard let plugins = try? await pluginsFacade.loadPlugins(using: config) else {
            logger.warning("Unable to load Plugin.swift manifest, fix and re-run in order to use plugin(s).")
            return .none
        }

        return plugins
    }
}
