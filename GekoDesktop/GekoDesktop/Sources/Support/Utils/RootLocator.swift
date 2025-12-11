import Foundation
import TSCBasic

public protocol RootDirectoryLocating {
    /// Given a path, it finds the root directory by traversing up the hierarchy.
    ///
    /// A root directory is defined as (in order of precedence):
    ///   - Directory containing a `Geko/` subdirectory.
    ///   - Directory containing a `Plugin.swift` manifest.
    ///   - Directory containing a `.git/` subdirectory.
    ///
    func locate(from path: AbsolutePath) -> AbsolutePath?
}

public final class RootDirectoryLocator: RootDirectoryLocating {
    private let fileManager = FileManager.default
    private let lock: NSLocking = NSRecursiveLock()
    /// This cache avoids having to traverse the directories hierarchy every time the locate method is called.
    private var _cache: [AbsolutePath: AbsolutePath] = [:]

    public init() {}

    public func locate(from path: AbsolutePath) -> AbsolutePath? {
        locate(from: path, source: path)
    }

    private func locate(from path: AbsolutePath, source: AbsolutePath) -> AbsolutePath? {
        if let cachedDirectory = cached(path: path) {
            return cachedDirectory
        } else if fileManager.fileExists(atPath:  path.appending(component: Constants.gekoDirectoryName).pathString) {
            cache(rootDirectory: path, for: source)
            return path
        } else if fileManager.fileExists(atPath:  path.appending(component: "Plugin.swift").pathString) {
            cache(rootDirectory: path, for: source)
            return path
        } else if fileManager.isFolder(path.appending(component: ".git")) {
            cache(rootDirectory: path, for: source)
            return path
        } else if !path.isRoot {
            return locate(from: path.parentDirectory, source: source)
        }
        return nil
    }

    // MARK: - Private

    private func cached(path: AbsolutePath) -> AbsolutePath? {
        cache()[path]
    }

    /// This method caches the root directory of path, and all its parents up to the root directory.
    /// - Parameters:
    ///   - rootDirectory: Path to the root directory.
    ///   - path: Path for which we are caching the root directory.
    private func cache(rootDirectory: AbsolutePath, for path: AbsolutePath) {
        var oldCache = cache()
        if path != rootDirectory {
            oldCache[path] = rootDirectory
            cache(rootDirectory: rootDirectory, for: path.parentDirectory)
        } else if path == rootDirectory {
            oldCache[path] = rootDirectory
        }
    }
    
    private func cache() -> [AbsolutePath: AbsolutePath] {
        defer { lock.unlock() }
        lock.lock()
        return _cache
    }
}
