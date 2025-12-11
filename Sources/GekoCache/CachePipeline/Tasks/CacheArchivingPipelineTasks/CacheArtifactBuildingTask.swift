import Foundation
import GekoSupport
import GekoCore

/// The task is responsible for sequentially building all cached modules into frameworks for each passed architecture
final class CacheArtifactBuildingTask: CacheArchivingTask {
    
    // MARK: - Attributes
    
    private let artifactBuilder: CacheArtifactBuilding
    
    // MARK: - Initialization
    
    init(artifactBuilder: CacheArtifactBuilding) {
        self.artifactBuilder = artifactBuilder
    }
    
    // MARK: - CacheArhivingTask
    
    func run(context: ArchivingContext) async throws {
        let logSpinner = LogSpinner()
        
        for (platform, scheme) in context.schemesByPlatform.sorted(by: { $0.key < $1.key }) {
            logSpinner.start(message: "Start building cacheable targets for platform \(platform.caseValue)")
            let outputDirectory = context.workDirectory.appending(component: scheme.name)
            try FileHandler.shared.createFolder(outputDirectory)
            try await artifactBuilder.build(
                graph: context.graph,
                scheme: scheme,
                projectTarget: XcodeBuildTarget(with: context.projectPath),
                derivedDataPath: nil,
                rosseta: false,
                configuration: context.cacheProfile.configuration,
                osVersion: context.cacheProfile.platforms[platform]?.os,
                deviceName: context.cacheProfile.platforms[platform]?.device,
                into: outputDirectory
            )
            logSpinner.stop()
        }
    }
}
