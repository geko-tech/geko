import Foundation
import GekoCore
import GekoGraph
import GekoLoader
import GekoSupport
import GekoDependencies

import struct ProjectDescription.AbsolutePath

final class CleanService {
    private let cacheDirectoryProviderFactory: CacheDirectoriesProviderFactoring
    private let logDirectoriesProvider: LogDirectoriesProviding
    
    init(
        cacheDirectoryProviderFactory: CacheDirectoriesProviderFactoring = CacheDirectoriesProviderFactory(),
        logDirectoriesProvider: LogDirectoriesProviding = LogDirectoriesProvider()
    ) {
        self.cacheDirectoryProviderFactory = cacheDirectoryProviderFactory
        self.logDirectoriesProvider = logDirectoriesProvider
    }

    func run(
        categories: [CleanCategory],
        path: String?,
        full: Bool
    ) throws {
        let path: AbsolutePath = try self.path(path)
        let manifestLoaderFactory = ManifestLoaderFactory()
        let manifestLoader = manifestLoaderFactory.createManifestLoader()
        let configLoader = ConfigLoader(manifestLoader: manifestLoader)
        let config = try configLoader.loadConfig(path: path)
        let cacheDirectoryProvider = try cacheDirectoryProviderFactory.cacheDirectories(config: config)

        for category in categories {
            switch category {
            case let .global(cacheCategory):
                try cleanCacheCategory(
                    cacheCategory,
                    cacheDirectoryProvider: cacheDirectoryProvider,
                    full: full
                )
            case .dependencies:
                try cleanDependencies(at: path)
            case .cocoapods:
                try cleanCocoapodsCaches(at: path, full: full)
            case .logs:
                try cleanupLogs(full: full)
            }
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

    private func cleanCacheCategory(
        _ cacheCategory: CacheCategory,
        cacheDirectoryProvider: CacheDirectoriesProviding,
        full: Bool
    ) throws {
        let directory = cacheDirectoryProvider.cacheDirectory(for: cacheCategory)
        if FileHandler.shared.exists(directory) {
            // TODO: Delete later before 1.0.0 release
            switch cacheCategory {
            case .plugins:
                try System.shared.chmod(.userWritable, path: directory, options: [.recursive])
            default:
                break
            }
            
            if full {
                try FileHandler.shared.delete(directory)
                logger.info("Successfully cleaned artifacts at path \(directory.pathString)", metadata: .success)
            } else {
                let folders: [AbsolutePath]
                switch cacheCategory {
                case .manifests, .generatedAutomationProjects, .plugins, .projectDescriptionHelpers, .tests:
                    folders = try FileHandler.shared.contentsOfDirectory(directory)
                case .builds:
                    folders = try FileHandler.shared.contentsOfDirectory(directory)
                        .flatMap { if FileHandler.shared.isFolder($0) { return try FileHandler.shared.contentsOfDirectory($0) } else { return [] } }
                        .flatMap { if FileHandler.shared.isFolder($0) { return try FileHandler.shared.contentsOfDirectory($0) } else { return [] } }
                }
                
                let deletedItems = try deleteOldFiles(folders)
                
                if deletedItems > 0 {
                    logger.info("Successfully cleaned \(deletedItems) artifacts at path \(directory.pathString)", metadata: .success)
                } else {
                    logger.info("No artifacts older than 7 days found at path \(directory.pathString)", metadata: .success)
                }
            }
        }
    }

    private func cleanDependencies(at path: AbsolutePath) throws {
        let dependenciesPath = path.appending(components: [Constants.gekoDirectoryName, Constants.DependenciesDirectory.name])
        if FileHandler.shared.exists(dependenciesPath) {
            let spmPath = dependenciesPath.appending(component: Constants.DependenciesDirectory.swiftPackageManagerDirectoryName)
            if FileHandler.shared.exists(spmPath) {
                try FileHandler.shared.delete(spmPath)
            }
            let cocoapodsPath = dependenciesPath.appending(component: "Cocoapods")
            if FileHandler.shared.exists(cocoapodsPath) {
                try FileHandler.shared.delete(cocoapodsPath)
            }
        }
        logger.info("Successfully cleaned dependencies at path \(dependenciesPath.pathString)", metadata: .success)
    }
    
    private func cleanCocoapodsCaches(at path: AbsolutePath, full: Bool) throws {
        let dependenciesPath = path.appending(components: [Constants.gekoDirectoryName, Constants.DependenciesDirectory.name])
        let pathProvider = try CocoapodsPathProvider(dependenciesDirectory: dependenciesPath)
        
        if full {
            if FileHandler.shared.exists(pathProvider.cacheContentsDir) {
                try FileHandler.shared.delete(pathProvider.cacheContentsDir)
                logger.info("Successfully cleaned cache at path \(pathProvider.cacheContentsDir.pathString)", metadata: .success)
            }
            if FileHandler.shared.exists(pathProvider.cacheGitContentsDir) {
                try FileHandler.shared.delete(pathProvider.cacheGitContentsDir)
                logger.info("Successfully cleaned cache at path \(pathProvider.cacheGitContentsDir.pathString)", metadata: .success)
            }
            if FileHandler.shared.exists(pathProvider.cacheGitSpecsDir) {
                try FileHandler.shared.delete(pathProvider.cacheGitSpecsDir)
                logger.info("Successfully cleaned cache at path \(pathProvider.cacheGitSpecsDir.pathString)", metadata: .success)
            }
            if FileHandler.shared.exists(pathProvider.userRepoCacheDir) {
                try FileHandler.shared.delete(pathProvider.userRepoCacheDir)
                logger.info("Successfully cleaned cache at path \(pathProvider.userRepoCacheDir.pathString)", metadata: .success)
            }
        } else {
            try cleanupCocoapodsCacheDir(pathProvider.cacheContentsDir)
            try cleanupCocoapodsCacheDir(pathProvider.cacheGitContentsDir)
            try cleanupCocoapodsCacheDir(pathProvider.cacheGitSpecsDir)
        }
    }
    
    private func cleanupCocoapodsCacheDir(_ path: AbsolutePath) throws {
        guard FileHandler.shared.exists(path) else { return }
        let pathDirContents = try FileHandler.shared
            .contentsOfDirectory(path)
            .filter(FileHandler.shared.isFolder(_:))
        
        let deletedItems = try deleteOldFiles(pathDirContents)
        if deletedItems > 0 {
            logger.info("Successfully cleaned \(deletedItems) cache artifacts older than 7 days at path \(path.pathString)", metadata: .success)
        } else {
            logger.info("No artifacts older than 7 days found at path \(path.pathString)", metadata: .success)
        }
    }
    
    private func cleanupLogs(full: Bool) throws {
        try LogCategory.allCases.forEach {
            let path = try logDirectoriesProvider.logDirectory(for: $0)
            if FileHandler.shared.exists(path) {
                if full {
                    try FileHandler.shared.delete(path)
                    logger.info("Successfully cleaned log folder at path \(path.pathString)", metadata: .success)
                } else {
                    let contents = try FileHandler.shared.contentsOfDirectory(path)
                    let deletedItems = try deleteOldFiles(contents)
                    if deletedItems > 0 {
                        logger.info("Successfully cleaned \(deletedItems) log artifacts older than 7 days at path \(path.pathString)", metadata: .success)
                    } else {
                        logger.info("No artifacts older than 7 days found at path \(path.pathString)", metadata: .success)
                    }
                }
            }
        }
    }
    
    private func deleteOldFiles(_ files: [AbsolutePath]) throws -> Int {
        guard let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        var deletedItems: Int = 0
        try files.forEach { path in
            let accessDate = try FileHandler.shared.fileAccessDate(path: path)
            guard
                FileHandler.shared.isFolder(path),
                accessDate < oneWeekAgo
            else { return }
            try FileHandler.shared.delete(path)
            deletedItems += 1
        }
        return deletedItems
    }
}
