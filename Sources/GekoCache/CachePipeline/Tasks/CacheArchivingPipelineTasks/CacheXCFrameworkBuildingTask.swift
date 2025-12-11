import Foundation
import GekoSupport
import GekoCore

/// Task is responsible for creating xcframeworks from previously collected artifacts
final class CacheXCFrameworkBuildingTask: CacheArchivingTask {
    
    // MARK: - Attributes
    
    private let xcframeworkBuilder: CacheXCFrameworkBuilding
    
    // MARK: - Initialization
    
    init(xcframeworkBuilder: CacheXCFrameworkBuilding) {
        self.xcframeworkBuilder = xcframeworkBuilder
    }
    
    // MARK: - CacheArchivingTask
    
    func run(context: ArchivingContext) async throws {
        guard case .xcframework = context.outputType else { return }
        
        let logSpinner = LogSpinner()
        logSpinner.start(message: "Start creating xcframeworks")
        
        try await xcframeworkBuilder.build(
            platforms: Array(context.schemesByPlatform.keys),
            workDirectory: context.workDirectory,
            outputDirectory: context.workDirectory,
            cacheableTarget: context.buildTargetsWithHash.map { $0.0 }
        )
        logSpinner.stop()
    }
}
