import Crypto
import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport

public protocol ProjectDescriptionHelpersHashing: AnyObject {
    /// Given the path to the directory that contains the helpers, it returns a hash that includes
    /// the hash of the files, the environment, as well as the versions of Swift and Geko.
    /// - Parameter helpersDirectory: Path to the helpers directory.
    func hash(helpersDirectory: AbsolutePath) throws -> String

    /// Gets the prefix hash for the given helpers directory.
    /// This is useful to uniquely identify a helpers directory in the cache.
    /// - Parameter helpersDirectory: Path to the helpers directory.
    func prefixHash(helpersDirectory: AbsolutePath) -> String
}

public final class ProjectDescriptionHelpersHasher: ProjectDescriptionHelpersHashing {
    /// Geko version.
    let gekoVersion: String

    private var cache: [AbsolutePath: String] = [:]
    private let lock = NSLock()

    public init(gekoVersion: String = Constants.version) {
        self.gekoVersion = gekoVersion
    }

    // MARK: - ProjectDescriptionHelpersHashing

    public func hash(helpersDirectory: AbsolutePath) throws -> String {
        lock.lock()
        if let cached = cache[helpersDirectory] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        var hasher = MD5Hasher()

        let fh = FileHandler.shared
        try fh
            .glob(helpersDirectory, glob: "**/*.swift")
            .sorted()
            .forEach {
                hasher.combine($0)
                try hasher.combine(fh.readFile($0))
            }
        let swiftVersion = try System.shared.swiftVersion()
        #if DEBUG
            let debug = true
        #else
            let debug = false
        #endif

        hasher.combine(swiftVersion)
        hasher.combine(gekoVersion)
        hasher.combine("\(debug)")

        let result = hasher.finalize()

        lock.lock()
        cache[helpersDirectory] = result
        lock.unlock()

        return result
    }

    public func prefixHash(helpersDirectory: AbsolutePath) -> String {
        let pathString = helpersDirectory.pathString
        let index = pathString.index(pathString.startIndex, offsetBy: 7)
        return String(helpersDirectory.pathString.md5[..<index])
    }
}
