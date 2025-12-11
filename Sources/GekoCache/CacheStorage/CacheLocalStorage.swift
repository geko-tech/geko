import Foundation
import ProjectDescription
import GekoCore
import GekoSupport
import GekoGraph

enum CacheLocalStorageError: FatalError, Equatable {
    case compiledArtifactNotFound(hash: String)

    var type: ErrorType {
        switch self {
        case .compiledArtifactNotFound: return .abort
        }
    }

    var description: String {
        switch self {
        case let .compiledArtifactNotFound(hash):
            return "xcframework with hash '\(hash)' not found in the local cache"
        }
    }
}

public final class CacheLocalStorage: CacheStoring {
    // MARK: - Attributes

    private let cacheDirectory: AbsolutePath
    private let cacheContextFolderProvider: CacheContextFolderProviding

    // MARK: - Init

    public convenience init(
        cacheDirectoriesProvider: CacheDirectoriesProviding,
        cacheContextFolderProvider: CacheContextFolderProviding
    ) {
        self.init(
            cacheDirectory: cacheDirectoriesProvider.cacheDirectory(for: .builds),
            cacheContextFolderProvider: cacheContextFolderProvider
        )
    }

    init(
        cacheDirectory: AbsolutePath,
        cacheContextFolderProvider: CacheContextFolderProviding
    ) {
        self.cacheDirectory = cacheDirectory
        self.cacheContextFolderProvider = cacheContextFolderProvider
    }

    // MARK: - CacheStoring

    public func exists(name: String, hash: String) throws -> Bool {
        let hashFolder = cacheDirectory.appending(components: [name, cacheContextFolderProvider.contextFolderName(), hash])
        let exists = lookupCompiledArtifact(directory: hashFolder, name: name) != nil
        if exists {
            CacheAnalytics.addLocalCacheTargetHit(name)
        }
        return exists
    }

    public func fetch(name: String, hash: String) throws -> AbsolutePath {
        let hashFolder = cacheDirectory.appending(components: [name, cacheContextFolderProvider.contextFolderName(), hash])
        guard let path = lookupCompiledArtifact(directory: hashFolder, name: name) else {
            throw CacheLocalStorageError.compiledArtifactNotFound(hash: hash)
        }
        try FileHandler.shared.fileUpdateAccessDate(path: hashFolder, date: Date())

        return path
    }

    public func store(name: String, hash: String, paths: [AbsolutePath]) throws {
        guard !paths.isEmpty else { return }
        if !FileHandler.shared.exists(cacheDirectory) {
            try FileHandler.shared.createFolder(cacheDirectory)
        }

        let hashFolder = cacheDirectory.appending(components: [name, cacheContextFolderProvider.contextFolderName(), hash])

        if !FileHandler.shared.exists(hashFolder) {
            try FileHandler.shared.createFolder(hashFolder)
        }
        try FileHandler.shared.fileUpdateAccessDate(path: hashFolder, date: Date())
        for sourcePath in paths {
            let destinationPath = hashFolder.appending(component: sourcePath.basename)
            if FileHandler.shared.exists(destinationPath) {
                try FileHandler.shared.delete(destinationPath)
            }
            try FileHandler.shared.copy(from: sourcePath, to: destinationPath)
        }
    }

    // MARK: - Private

    private func lookupCompiledArtifact(directory: AbsolutePath, name: String) -> AbsolutePath? {
        let extensions = ["framework", "xcframework", "swiftmodule"]
        for ext in extensions {
            if let filePath = FileHandler.shared.glob(directory, glob: "*.\(ext)").first { return filePath }
        }

        let bundleFolder = directory.appending(component: name)
        if FileHandler.shared.exists(bundleFolder) {
            return bundleFolder
        }
        
        return nil
    }
}
