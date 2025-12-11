import Foundation
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoCore
import GekoSupport

public protocol ManifestFilesLocating: AnyObject {
    /// It locates the manifest files in the locating directory.
    /// - Parameter locatingPath: Directory for which the manifest files will be obtained.
    func locateManifests(at locatingPath: AbsolutePath) -> [(Manifest, AbsolutePath)]

    /// It locates all manifest extension files in the same diredtory as
    /// the manifest.
    /// Manifest extension files are files with names such as `Project+Extension.swift` 
    /// and are used to be able to split large manifests into separate files.
    /// - Parameter manifest: Manifest type
    /// - Parameter path: path to the directory containing manifest
    func locateManifestExtensionFiles(for manifest: Manifest, at path: AbsolutePath) throws -> [AbsolutePath]

    /// It locates all plugin manifest files under the the root directory (as defined in `RootDirectoryLocator`).
    /// - Parameters:
    ///     - locatingPath: Directory for which the **plugin** manifest files will be obtained.
    ///     - excluding: Relative glob patterns for excluded files.
    ///     - onlyCurrentDirectory: If true, search for plugin manifests only in the directory of `locatingPath`
    func locatePluginManifests(
        at locatingPath: AbsolutePath,
        excluding: [String],
        onlyCurrentDirectory: Bool
    ) -> [AbsolutePath]

    /// It locates all project and workspace manifest files under the root directory (as defined in `RootDirectoryLocator`).
    /// - Parameters:
    ///     - locatingPath: Directory for which the **project** and **workspace** manifest files will be obtained.
    ///     - excluding: Relative glob patterns for excluded files.
    ///     - onlyCurrentDirectory: If true, search for manifests only in the directory of `locatingPath`
    func locateProjectManifests(
        at locatingPath: AbsolutePath,
        excluding: [String],
        onlyCurrentDirectory: Bool
    ) -> [ManifestFilesLocator.ProjectManifest]

    /// It traverses up the directory hierarchy until it finds a `Config.swift` file.
    /// - Parameter locatingPath: Path from where to do the lookup.
    func locateConfig(at locatingPath: AbsolutePath) -> AbsolutePath?

    /// It traverses up the directory hierarchy until it finds a `Dependencies.swift` file.
    /// - Parameter locatingPath: Path from where to do the lookup.
    func locateDependencies(at locatingPath: AbsolutePath) -> AbsolutePath?

    /// It traverses up the directory hierarchy until it finds a `Package.swift` file
    /// - Parameter locatingPath: Path from where to do the lookup
    func locatePackageManifest(
        at locatingPath: AbsolutePath
    ) -> AbsolutePath?
}

public final class ManifestFilesLocator: ManifestFilesLocating {
    /// Utility to locate the root directory of the project
    let rootDirectoryLocator: RootDirectoryLocating

    public init(rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator()) {
        self.rootDirectoryLocator = rootDirectoryLocator
    }

    public func locateManifests(at locatingPath: AbsolutePath) -> [(Manifest, AbsolutePath)] {
        Manifest.allCases.compactMap { manifest in
            let path = locatingPath.appending(component: manifest.fileName(locatingPath))
            if FileHandler.shared.exists(path) { return (manifest, path) }
            return nil
        }
    }

    public func locateManifestExtensionFiles(for manifest: Manifest, at path: AbsolutePath) throws -> [AbsolutePath] {
        let directory = path.parentDirectory
        let manifestFileNameComponents = manifest.fileName(path).components(separatedBy: ".")
        let (manifestBasename, manifestExt) = (manifestFileNameComponents[0], manifestFileNameComponents[1])
        let manifestExtensionBasename = "\(manifestBasename)+"
        let manifestExtensions = try FileHandler.shared.contentsOfDirectory(directory)
            .filter { entry in
                guard
                    entry.basename.starts(with: manifestExtensionBasename),
                    entry.extension == manifestExt
                else {
                    return false
                }

                return !FileHandler.shared.isFolder(entry)
            }

        return manifestExtensions
    }

    public func locatePluginManifests(
        at locatingPath: AbsolutePath,
        excluding: [String],
        onlyCurrentDirectory: Bool
    ) -> [AbsolutePath] {
        if onlyCurrentDirectory {
            let pluginPath = locatingPath.appending(
                component: Manifest.plugin.fileName(locatingPath)
            )
            guard FileHandler.shared.exists(pluginPath) else { return [] }
            return [pluginPath]
        } else {
            let path = rootDirectoryLocator.locate(from: locatingPath) ?? locatingPath

            let pluginsPaths = fetchGekoManifestsFilePaths(at: path)
                .filter { $0.basename == Manifest.plugin.fileName(path) }
                .filter { path in
                    !excluding.contains { pattern in match(path, pattern: pattern) }
                }

            return Array(pluginsPaths)
        }
    }

    private func match(_ path: AbsolutePath, pattern: String) -> Bool {
        fnmatch(pattern, path.pathString, 0) != FNM_NOMATCH
    }

    var cacheGekoManifestsFilePaths = [AbsolutePath: Set<AbsolutePath>]()

    private func fetchGekoManifestsFilePaths(at path: AbsolutePath) -> Set<AbsolutePath> {
        if let cachedGekoManifestsFilePaths = cacheGekoManifestsFilePaths[path] {
            return cachedGekoManifestsFilePaths
        }
        let fileNamesCandidates: Set<String> = [
            Manifest.project.fileName(path),
            Manifest.workspace.fileName(path),
            Manifest.plugin.fileName(path),
        ]

        var gekoManifestsFilePaths = [AbsolutePath]()

        let enumerator = FileManager.default.enumerator(
            at: path.url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let candidateURL = enumerator?.nextObject() as? URL {
            guard candidateURL.pathExtension == "swift",
                  fileNamesCandidates.contains(candidateURL.lastPathComponent)
            else {
                continue
            }
            // Symlinks need to be resolved for resulting absolute URLs to point to the right place.
            let url = candidateURL.resolvingSymlinksInPath()
            let absolutePath = AbsolutePath(stringLiteral: url.path)
            if hasValidManifestContent(absolutePath) {
                gekoManifestsFilePaths.append(absolutePath)
            }
        }

        let cachedGekoManifestsFilePaths = Set(gekoManifestsFilePaths)
        cacheGekoManifestsFilePaths[path] = cachedGekoManifestsFilePaths
        return cachedGekoManifestsFilePaths
    }

    private func hasValidManifestContent(_ path: AbsolutePath) -> Bool {
        guard let content = try? FileHandler.shared.readTextFile(path) else { return false }

        let gekoManifestSignature = "import ProjectDescription"
        return content.contains(gekoManifestSignature) || content.isEmpty
    }

    /// Project manifest returned by `locateProjectManifests`
    public struct ProjectManifest: Equatable {
        public let manifest: Manifest
        public let path: AbsolutePath

        public init(
            manifest: Manifest,
            path: AbsolutePath
        ) {
            self.manifest = manifest
            self.path = path
        }
    }

    public func locateProjectManifests(
        at locatingPath: AbsolutePath,
        excluding: [String],
        onlyCurrentDirectory: Bool
    ) -> [ProjectManifest] {
        if onlyCurrentDirectory {
            return [
                ProjectManifest(
                    manifest: Manifest.project,
                    path: locatingPath.appending(
                        component: Manifest.project.fileName(locatingPath)
                    )
                ),
                ProjectManifest(
                    manifest: Manifest.workspace,
                    path: locatingPath.appending(
                        component: Manifest.workspace.fileName(locatingPath)
                    )
                ),
            ]
            .filter { FileHandler.shared.exists($0.path) }
        } else {
            let path = rootDirectoryLocator.locate(from: locatingPath) ?? locatingPath

            let manifestsFilePaths = fetchGekoManifestsFilePaths(at: path)
                .filter { path in
                    !excluding.contains { pattern in match(path, pattern: pattern) }
                }
            let projectsPaths = manifestsFilePaths
                .filter { $0.basename == Manifest.project.fileName(path) }
                .map {
                    ProjectManifest(
                        manifest: Manifest.project,
                        path: $0
                    )
                }
            let workspacesPaths = manifestsFilePaths
                .filter { $0.basename == Manifest.workspace.fileName(path) }
                .map {
                    ProjectManifest(
                        manifest: Manifest.workspace,
                        path: $0
                    )
                }

            return projectsPaths + workspacesPaths
        }
    }

    public func locateConfig(at locatingPath: AbsolutePath) -> AbsolutePath? {
        // swiftlint:disable:next force_try
        let subPath = try! RelativePath(validating: "\(Constants.gekoDirectoryName)/\(Manifest.config.fileName(locatingPath))")
        return traverseAndLocate(at: locatingPath, appending: subPath)
    }

    public func locateDependencies(at locatingPath: AbsolutePath) -> AbsolutePath? {
        let subPath =
            // swiftlint:disable:next force_try
            try! RelativePath(validating: "\(Constants.gekoDirectoryName)/\(Manifest.dependencies.fileName(locatingPath))")
        return traverseAndLocate(at: locatingPath, appending: subPath)
    }

    public func locatePackageManifest(at locatingPath: AbsolutePath) -> AbsolutePath? {
        let subPath =
            // swiftlint:disable:next force_try
            try! RelativePath(validating: "\(Constants.gekoDirectoryName)/Package.swift")
        return traverseAndLocate(at: locatingPath, appending: subPath)
    }

    // MARK: - Helpers

    private func traverseAndLocate(at locatingPath: AbsolutePath, appending subpath: RelativePath) -> AbsolutePath? {
        let manifestPath = locatingPath.appending(subpath)

        if FileHandler.shared.exists(manifestPath) {
            return manifestPath
        } else if locatingPath != .root {
            return traverseAndLocate(at: locatingPath.parentDirectory, appending: subpath)
        } else {
            return nil
        }
    }
}
