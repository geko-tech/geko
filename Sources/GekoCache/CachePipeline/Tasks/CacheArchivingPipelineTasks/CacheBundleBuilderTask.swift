import Foundation
import GekoCore
import GekoSupport

/// Task responsible for prepare bundles by distributing them into folders depending on the platform for which it was compiled
/// Example: ios/mybundle.bundle, tvos/mybundle.bundle
final class CacheBundleBuilderTask: CacheArchivingTask {
    
    // MARK: - Attributes
    
    private let bundlesBuilder: CacheBundleBuilding
    
    // MARK: - Initialization
    
    init(bundlesBuilder: CacheBundleBuilding = CacheBundleBuilder()) {
        self.bundlesBuilder = bundlesBuilder
    }
    
    // MARK: - CacheArchivingTask
    
    func run(context: ArchivingContext) async throws {
        let logSpinner = LogSpinner()
        logSpinner.start(message: "Start preparing bundles")
        try await bundlesBuilder.prepareBundles(
            platforms: Array(context.schemesByPlatform.keys),
            workDirectory: context.workDirectory,
            outputDirectory: context.workDirectory,
            cacheableTarget: context.buildTargetsWithHash.map { $0.0 }
        )
        logSpinner.stop()
    }
}
