import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport

final class CocoapodsCleanupService {
    private let pathProvider: CocoapodsPathProviding
    private let fileHandler: FileHandling

    init(
        pathProvider: CocoapodsPathProviding,
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.pathProvider = pathProvider
        self.fileHandler = fileHandler
    }

    func cleanup() throws {
        logger.info("Cleaning up")

        try cleanupCacheDir(
            pathProvider.cacheContentsDir,
            usedPaths: pathProvider.usedCacheContentsDirs
        )
        try cleanupCacheDir(
            pathProvider.cacheGitContentsDir,
            usedPaths: pathProvider.usedCacheGitSpecContentDirs
        )
        try cleanupCacheDir(
            pathProvider.cacheGitSpecsDir,
            usedPaths: pathProvider.usedCacheGitSpecJsonPaths
        )
        try cleanupDependenciesDir()
    }

    private func cleanupCacheDir(
        _ path: AbsolutePath,
        usedPaths: borrowing Set<AbsolutePath>
    ) throws {
        guard fileHandler.exists(path) else { return }
        try modifyAcceesDateForUsedPaths(usedPaths: usedPaths)
        let pathDirContents = try fileHandler
            .contentsOfDirectory(path)
            .filter(fileHandler.isFolder(_:))
        
        for dir in pathDirContents {
            let dirContents = try fileHandler
                .contentsOfDirectory(dir)
                .filter(fileHandler.isFolder(_:))
                .map { ($0, try fileHandler.fileAccessDate(path: $0)) }
                .sorted(by: { $0.1 > $1.1 })
                .dropFirst(3)
            for (pathToCleanUp, _) in dirContents {
                if !usedPaths.contains(pathToCleanUp) {
                    try fileHandler.delete(pathToCleanUp)
                }
            }
        }
    }
    
    private func modifyAcceesDateForUsedPaths(usedPaths: Set<AbsolutePath>) throws {
        let date = Date()
        for usedPath in usedPaths {
            try fileHandler.fileUpdateAccessDate(path: usedPath, date: date)
        }
    }

    private func cleanupDependenciesDir() throws {
        let targetSupportDir = pathProvider.targetSupportDir
        let frameworkBundlesDir = pathProvider.frameworkBundlesDir
        let dirPath = pathProvider.dependenciesDir
        guard fileHandler.exists(dirPath) else { return }
        let dirContents = try fileHandler.contentsOfDirectory(dirPath)

        for dir in dirContents {
            guard !pathProvider.usedDependencyDirs.contains(dir),
                  dir != targetSupportDir,
                  dir != frameworkBundlesDir
            else {
                continue
            }

            logger.info("Removing \(dir.basename)", metadata: .subsection)
            try fileHandler.delete(dir)
        }
    }
}
