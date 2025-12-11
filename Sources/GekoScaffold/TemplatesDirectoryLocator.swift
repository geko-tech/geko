import Foundation
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoCore
import GekoSupport

public protocol TemplatesDirectoryLocating {
    /// Returns the path to the geko built-in templates directory if it exists.
    func locateGekoTemplates() -> AbsolutePath?

    /// Returns the path to the user-defined templates directory if it exists.
    /// - Parameter at: Path from which we traverse the hierarchy to obtain the templates directory.
    func locateUserTemplates(at: AbsolutePath) -> AbsolutePath?

    /// - Returns: All available directories with defined templates (user-defined and built-in)
    func templateDirectories(at path: AbsolutePath) throws -> [AbsolutePath]

    /// - Parameter path: The path to the `Templates` directory for a plugin.
    /// - Returns: All available directories defined for the plugin at the given path
    func templatePluginDirectories(at path: AbsolutePath) throws -> [AbsolutePath]
}

public final class TemplatesDirectoryLocator: TemplatesDirectoryLocating {
    private let rootDirectoryLocator: RootDirectoryLocating

    /// Default constructor.
    public init(rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator()) {
        self.rootDirectoryLocator = rootDirectoryLocator
    }

    // MARK: - TemplatesDirectoryLocating

    public func locateGekoTemplates() -> AbsolutePath? {
        #if DEBUG
            let maybeBundlePath: AbsolutePath?
            if let sourceRoot = ProcessEnv.vars["GEKO_CONFIG_SRCROOT"] {
                maybeBundlePath = try? AbsolutePath(validatingAbsolutePath: sourceRoot).appending(component: "Templates")
            } else {
                // Used only for debug purposes to find templates in your geko working directory
                // `bundlePath` points to geko/Templates
                maybeBundlePath = try? AbsolutePath(validatingAbsolutePath: #file.replacingOccurrences(of: "file://", with: ""))
                    .removingLastComponent()
                    .removingLastComponent()
                    .removingLastComponent()
            }
        #else
            let maybeBundlePath = try? AbsolutePath(validatingAbsolutePath: Bundle(for: TemplatesDirectoryLocator.self).bundleURL.path)
        #endif
        guard let bundlePath = maybeBundlePath else { return nil }
        let paths = [
            bundlePath,
            bundlePath.parentDirectory,
            /**
                == Homebrew directory structure ==
                x.y.z/
                   bin/
                       geko
                   share/
                       geko/
                           Templates
                */
            bundlePath.parentDirectory.appending(try! RelativePath(validating: "share/geko")),
            // swiftlint:disable:previous force_try
        ]
        let candidates = paths.map { path in
            path.appending(component: Constants.templatesDirectoryName)
        }
        return candidates.first(where: FileHandler.shared.exists)
    }

    public func locateUserTemplates(at: AbsolutePath) -> AbsolutePath? {
        guard let customTemplatesDirectory = locate(from: at) else { return nil }
        if !FileHandler.shared.exists(customTemplatesDirectory) { return nil }
        return customTemplatesDirectory
    }

    public func templateDirectories(at path: AbsolutePath) throws -> [AbsolutePath] {
        let gekoTemplatesDirectory = locateGekoTemplates()
        let gekoTemplates = try gekoTemplatesDirectory.map(FileHandler.shared.contentsOfDirectory) ?? []
        let userTemplatesDirectory = locateUserTemplates(at: path)
        let userTemplates = try userTemplatesDirectory.map(FileHandler.shared.contentsOfDirectory) ?? []
        return (gekoTemplates + userTemplates).filter(FileHandler.shared.isFolder)
    }

    public func templatePluginDirectories(at path: AbsolutePath) throws -> [AbsolutePath] {
        try FileHandler.shared.contentsOfDirectory(path).filter(FileHandler.shared.isFolder)
    }

    // MARK: - Helpers

    private func locate(from path: AbsolutePath) -> AbsolutePath? {
        guard let rootDirectory = rootDirectoryLocator.locate(from: path) else { return nil }
        return rootDirectory.appending(components: Constants.gekoDirectoryName, Constants.templatesDirectoryName)
    }
}
