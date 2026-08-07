import Foundation
import GekoSupport
import GekoCore
import ProjectDescription

/// The task is responsible for sequentially building all cached modules into frameworks for each passed architecture
final class CacheArtifactBuildingTask: CacheArchivingTask {
    
    // MARK: - Attributes
    
    private let buildableProducts: [Product] = [.framework, .staticFramework]
    private let artifactBuilder: CacheArtifactBuilding
    
    // MARK: - Initialization
    
    init(artifactBuilder: CacheArtifactBuilding) {
        self.artifactBuilder = artifactBuilder
    }
    
    // MARK: - CacheArhivingTask
    
    func run(context: ArchivingContext) async throws {
        let logSpinner = LogSpinner()
        let bundleTargets = context.buildTargetsWithHash.filter { $0.0.target.product == .bundle }.map { $0.0.target.name }
        let progressTracker = ProgressTracker(elements: context.buildTargetsWithHash.map { $0.0.target.name })
        
        for (platform, scheme) in context.schemesByPlatform.sorted(by: { $0.key < $1.key }) {
            logSpinner.start(message: "Building cacheable targets for platform \(platform.caseValue)")
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
                into: outputDirectory,
                eventHandler: { event in
                    let progress: ProgressTracker<String>.Progress?
                    switch event {
                    case let .targetCompilationStarted(targetName):
                        progress = progressTracker.register(targetName)
                    case let .processInfoPlistFile(targetName):
                        guard bundleTargets.contains(targetName) else { return }
                        progress = progressTracker.register(targetName)
                    default:
                        return
                    }
                    guard let progress else { return }
                    logSpinner.update(message: self.progressMessage(progress, platform: platform))
                }
            )
            logSpinner.stop(message: "Built all targets for platform \(platform.caseValue)")
        }
    }
    
    private func progressMessage(
        _ progress: ProgressTracker<String>.Progress,
        platform: Platform
    ) -> String {
        """
        Building \
        [\(progress.completedCount)/\(progress.totalCount)] \
        \(progress.current) \
        for \(platform.caseValue)
        """
    }
}
