import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

public protocol CacheBundleBuilding {
    
    /// Prepare bundles by distributing them into folders depending on the platform for which it was compiled
    /// Example: ios/mybundle.bundle, tvos/mybundle.bundle
    func prepareBundles(
        platforms: [Platform],
        workDirectory: AbsolutePath,
        outputDirectory: AbsolutePath,
        cacheableTarget: [GraphTarget]
    ) async throws
}

public final class CacheBundleBuilder: CacheBundleBuilding {
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - CacheBundleBuilding
    
    public func prepareBundles(
        platforms: [Platform],
        workDirectory: AbsolutePath,
        outputDirectory: AbsolutePath,
        cacheableTarget: [GraphTarget]
    ) async throws {
        let bundlesDir = outputDirectory.appending(component: CacheConstants.bundleOutputFolderName)
        if !FileHandler.shared.exists(bundlesDir) {
            try FileHandler.shared.createFolder(bundlesDir)
        }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for target in cacheableTarget {
                guard target.target.product == .bundle else { continue }
                group.addTask {
                    for platform in platforms {
                        let platformBundlePath = workDirectory.appending(components: [
                            "\(CacheConstants.cacheProjectName)-\(platform.caseValue)",
                            "\(target.target.productName).bundle"
                        ])
                        if FileHandler.shared.exists(platformBundlePath) {
                            let to = bundlesDir.appending(components: [
                                target.target.name,
                                platform.rawValue
                            ])
                            try FileHandler.shared.createFolder(to)
                            try FileHandler.shared.move(from: platformBundlePath, to: to.appending(component: "\(target.target.productName).bundle"))
                        }
                    }
                }
            }
            
            try await group.waitForAll()
        }
    }
}
