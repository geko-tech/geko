import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport

public enum ManifestLoaderError: FatalError, Equatable {
    case projectDescriptionNotFound(AbsolutePath)
    case unexpectedOutput(AbsolutePath)
    case manifestNotFound(Manifest?, AbsolutePath)
    case manifestCachingFailed(Manifest?, AbsolutePath)
    case manifestLoadingFailed(path: AbsolutePath, data: Data, context: String)

    public static func manifestNotFound(_ path: AbsolutePath) -> ManifestLoaderError {
        .manifestNotFound(nil, path)
    }

    public var description: String {
        switch self {
        case let .projectDescriptionNotFound(path):
            return "Couldn't find ProjectDescription.framework at path \(path.pathString)"
        case let .unexpectedOutput(path):
            return "Unexpected output trying to parse the manifest at path \(path.pathString)"
        case let .manifestNotFound(manifest, path):
            return "\(manifest?.fileName(path) ?? "Manifest") not found at path \(path.pathString)"
        case let .manifestCachingFailed(manifest, path):
            return "Could not cache \(manifest?.fileName(path) ?? "Manifest") at path \(path.pathString)"
        case let .manifestLoadingFailed(path, _, context):
            return """
            Unable to load manifest at \(path.pathString.bold())
            \(context)
            """
        }
    }

    public var type: ErrorType {
        switch self {
        case .unexpectedOutput:
            return .bug
        case .projectDescriptionNotFound:
            return .bug
        case .manifestNotFound:
            return .abort
        case .manifestCachingFailed:
            return .abort
        case .manifestLoadingFailed:
            return .abort
        }
    }
}

public protocol ManifestLoading {
    /// Loads the Config.swift in the given directory.
    ///
    /// - Parameter path: Path to the directory that contains the Config.swift file.
    /// - Returns: Loaded Config.swift file.
    /// - Throws: An error if the file has a syntax error.
    func loadConfig(at path: AbsolutePath) throws -> ProjectDescription.Config

    /// Loads the Project.swift in the given directory.
    /// - Parameter path: Path to the directory that contains the Project.swift.
    func loadProject(at path: AbsolutePath) throws -> ProjectDescription.Project

    /// Loads the Workspace.swift in the given directory.
    /// - Parameter path: Path to the directory that contains the Workspace.swift
    func loadWorkspace(at path: AbsolutePath) throws -> ProjectDescription.Workspace

    /// Loads the name_of_template.swift in the given directory.
    /// - Parameter path: Path to the directory that contains the name_of_template.swift
    func loadTemplate(at path: AbsolutePath) throws -> ProjectDescription.Template

    /// Loads the Dependencies.swift in the given directory
    /// - Parameters:
    /// - Parameter path: Path to the directory that contains the Package.swift
    func loadDependencies(at path: AbsolutePath) throws -> ProjectDescription.Dependencies

    /// Loads the `PackageSettings` from `Package.swift` in the given directory
    /// -  path: Path to the directory that contains Dependencies.swift
    func loadPackageSettings(at path: AbsolutePath) throws -> ProjectDescription.PackageSettings

    /// Loads the Plugin.swift in the given directory.
    /// - Parameter path: Path to the directory that contains Plugin.swift
    func loadPlugin(at path: AbsolutePath) throws -> ProjectDescription.Plugin

    /// List all the manifests in the given directory.
    /// - Parameter path: Path to the directory whose manifest files will be returned.
    func manifests(at path: AbsolutePath) -> Set<Manifest>

    /// Verifies that there is a project or workspace manifest at the given path, or throws an error otherwise.
    func validateHasProjectOrWorkspaceManifest(at path: AbsolutePath) throws

    /// Registers plugins that will be used within the manifest loading process.
    /// - Parameter plugins: The plugins to register.
    func register(plugins: Plugins) throws
    
    /// Deletes old manifests.
    func cleanupOldManifests() throws -> [SideEffectDescriptor]
}
