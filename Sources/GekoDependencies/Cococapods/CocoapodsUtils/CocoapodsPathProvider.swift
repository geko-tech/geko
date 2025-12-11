import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport

public protocol CocoapodsPathProviding {
    var lockfilePath: AbsolutePath { get }

    var dependenciesDir: AbsolutePath { get }
    var targetSupportDir: AbsolutePath { get }
    var frameworkBundlesDir: AbsolutePath { get }

    func repoCacheDir(repoName: String) -> AbsolutePath

    func dependencyDir(name: String) -> AbsolutePath
    func dependencyTargetSupportDir(name: String) -> AbsolutePath
    func dependencyFrameworkBundle(bundle: String) -> AbsolutePath

    var cacheDir: AbsolutePath { get }
    var cacheContentsDir: AbsolutePath { get }
    var cacheSpecsDir: AbsolutePath { get }
    var cacheGitContentsDir: AbsolutePath { get }
    var cacheGitSpecsDir: AbsolutePath { get }

    func cacheSpecNameDir(name: String) -> AbsolutePath
    func cacheSpecContentDir(
        name: String,
        version: String,
        checksum: String
    ) -> AbsolutePath

    func cacheGitSpecContentDir(name: String, hash: String) -> AbsolutePath
    func cacheGitSpecJsonDir(name: String) -> AbsolutePath
    func cacheGitSpecJsonPath(name: String, hash: String) -> AbsolutePath

    var usedCacheContentsDirs: Set<AbsolutePath> { borrowing get }
    var usedCacheGitSpecContentDirs: Set<AbsolutePath> { borrowing get }
    var usedCacheGitSpecJsonPaths: Set<AbsolutePath> { borrowing get }
    var usedDependencyDirs: Set<AbsolutePath> { borrowing get }
}

public final class CocoapodsPathProvider: CocoapodsPathProviding {
    private let rootDependenciesDirectory: AbsolutePath

    public let lockfilePath: AbsolutePath

    public let userRepoCacheDir: AbsolutePath
    public let userCacheDir: AbsolutePath

    public let cacheDir: AbsolutePath
    public let cacheContentsDir: AbsolutePath
    public let cacheSpecsDir: AbsolutePath
    public let cacheGitContentsDir: AbsolutePath
    public let cacheGitSpecsDir: AbsolutePath

    public let dependenciesDir: AbsolutePath
    public let targetSupportDir: AbsolutePath
    public let frameworkBundlesDir: AbsolutePath

    public var usedCacheContentsDirs = Set<AbsolutePath>()
    public var usedCacheSpecsDirs = Set<AbsolutePath>()
    public var usedCacheGitSpecContentDirs = Set<AbsolutePath>()
    public var usedCacheGitSpecJsonPaths = Set<AbsolutePath>()
    public var usedDependencyDirs = Set<AbsolutePath>()

    private var lock = NSLock()

    public init(dependenciesDirectory: AbsolutePath) throws {
        rootDependenciesDirectory = dependenciesDirectory

        lockfilePath = dependenciesDirectory.appending(component: Constants.DependenciesDirectory.cocoapodsLockfileName)

        userRepoCacheDir = try resolveUserRepoCacheDir()
        userCacheDir = try resolveUserCacheDir()

        cacheDir = userCacheDir.appending(components: "Geko", "Cocoapods")
        cacheContentsDir = cacheDir.appending(component: "Release")
        cacheSpecsDir = cacheDir.appending(components: "Specs", "Release")
        cacheGitContentsDir = cacheDir.appending(component: "External")
        cacheGitSpecsDir = cacheDir.appending(components: "Specs", "External")

        dependenciesDir = rootDependenciesDirectory.appending(component: "Cocoapods")
        targetSupportDir = dependenciesDir.appending(component: "TargetSupportFiles")
        frameworkBundlesDir = targetSupportDir.appending(component: "FrameworkBundles")
    }

    // MARK: Repo cache

    public func repoCacheDir(repoName: String) -> AbsolutePath {
        userRepoCacheDir.appending(component: repoName)
    }

    // MARK: Dependencies directory

    public func dependencyDir(name: String) -> AbsolutePath {
        let result = dependenciesDir.appending(component: name)
        lock.lock()
        usedDependencyDirs.insert(result)
        lock.unlock()
        return result
    }

    public func dependencyTargetSupportDir(name: String) -> AbsolutePath {
        targetSupportDir.appending(component: name)
    }

    public func dependencyFrameworkBundle(bundle: String) -> AbsolutePath {
        frameworkBundlesDir.appending(component: bundle)
    }

    // MARK: CDN cache

    public func cacheSpecNameDir(name: String) -> AbsolutePath {
        cacheContentsDir.appending(component: name)
    }

    public func cacheSpecContentDir(
        name: String,
        version: String,
        checksum: String
    ) -> AbsolutePath {
        let result = cacheSpecNameDir(name: name)
            .appending(component: "\(version)-\(checksum)")
        lock.lock()
        usedCacheContentsDirs.insert(result)
        lock.unlock()
        return result
    }

    // MARK: - Git cache

    public func cacheGitSpecContentDir(name: String, hash: String) -> AbsolutePath {
        let result = cacheGitContentsDir
            .appending(component: name)
            .appending(component: hash)
        lock.lock()
        usedCacheGitSpecContentDirs.insert(result)
        lock.unlock()
        return result
    }

    public func cacheGitSpecJsonDir(name: String) -> AbsolutePath {
        cacheGitSpecsDir.appending(component: name)
    }

    public func cacheGitSpecJsonPath(name: String, hash: String) -> AbsolutePath {
        let result = cacheGitSpecJsonDir(name: name)
            .appending(component: "\(hash).json")
        lock.lock()
        usedCacheGitSpecJsonPaths.insert(result)
        lock.unlock()
        return result
    }
}

private func resolveUserRepoCacheDir() throws -> AbsolutePath {
    if let dir = ProcessInfo.processInfo
        .environment[Constants.EnvironmentVariables.cocoapodsRepoCacheDirectory]
    {
        let dirPath = try! AbsolutePath(validatingAbsolutePath: dir)
        return dirPath
    }

    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let homeDirPath = try! AbsolutePath(validatingAbsolutePath: homeDir.path)
    return homeDirPath
        .appending(components: [".geko", "CocoapodsRepoCache"])
}

private func resolveUserCacheDir() throws -> AbsolutePath {
    if let dir = ProcessInfo.processInfo
        .environment[Constants.EnvironmentVariables.cocoapodsCacheDirectory]
    {
        let dirPath = try AbsolutePath(validatingAbsolutePath: dir)
        return dirPath
    }

    let dirUrl = try FileManager.default.url(
        for: .cachesDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let dirPath = try AbsolutePath(validatingAbsolutePath: dirUrl.path())
    return dirPath
}
