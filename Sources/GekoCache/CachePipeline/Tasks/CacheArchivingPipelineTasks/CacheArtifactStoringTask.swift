import Foundation
import GekoCore
import GekoSupport
import struct ProjectDescription.AbsolutePath

/// Storing task responsible for storing all collected artifacts from previous caching stages
final class CacheArtifactStoringTask: CacheArchivingTask {
    
    // MARK: - Attributes
    
    private let cache: Cache
    
    // MARK: - Initialization
    
    init(cache: Cache) {
        self.cache = cache
    }
    
    // MARK: - CacheArchivingTask
    
    func run(context: ArchivingContext) async throws {
        let logSpinner = LogSpinner()
        let targetsToStore = context.buildTargetsWithHash.map(\.0.target.name).sorted().joined(separator: ", ")
        logSpinner.start(message: "Storing \(context.buildTargetsWithHash.count) cacheable targets")
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (target, hash) in context.buildTargetsWithHash {
                let glob: String
                let artifactPath: AbsolutePath
                
                if target.target.product.isFramework {
                    switch context.outputType {
                    case .framework:
                        glob = "*/\(target.target.productName).\(context.outputType.productExtension)"
                        artifactPath = context.workDirectory
                    case .xcframework:
                        glob = "\(target.target.productName).\(context.outputType.productExtension)"
                        artifactPath = context.workDirectory.appending(component: CacheConstants.xcframeworkOutputFolderName)
                    }
                } else {
                    glob = "\(target.target.name)"
                    artifactPath = context.workDirectory.appending(component: CacheConstants.bundleOutputFolderName)
                }
                
                group.addTask {
                    try await self.cache.store(
                        name: target.target.name,
                        hash: hash,
                        paths: [FileHandler.shared.glob(
                            artifactPath,
                            glob: glob
                        ).first].compactMap { $0 }
                    )
                }
            }
            
            try await group.waitForAll()
        }
        logSpinner.stop()
        logger.notice("Stored target: \(targetsToStore)")
    }
}
