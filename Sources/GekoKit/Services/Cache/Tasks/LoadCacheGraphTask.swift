import Foundation
import ProjectDescription
import GekoCache
import GekoSupport
import GekoGraph

/// Loads graph and focus modules
final class LoadCacheGraphTask: CacheTask {
    
    // MARK: - Attributes
    
    private let generatorFactory: GeneratorFactorying
    private let sideEffectDescriptorExecutor: SideEffectDescriptorExecuting

    // MARK: - Initialization
    
    init(
        generatorFactory: GeneratorFactorying,
        sideEffectDescriptorExecutor: SideEffectDescriptorExecuting = SideEffectDescriptorExecutor()
    ) {
        self.generatorFactory = generatorFactory
        self.sideEffectDescriptorExecutor = sideEffectDescriptorExecutor
    }
    
    func run(context: inout CacheContext) async throws {
        let generator = try generatorFactory.cache(
            config: context.config,
            focusedTargets: context.userFocusedTargets,
            cacheProfile: context.cacheProfile,
            focusDirectDependencies: context.focusDirectDependencies,
            focusTests: context.focusTests,
            unsafe: context.unsafe,
            dependenciesOnly: context.dependenciesOnly,
            scheme: context.scheme
        )
        
        let (graph, sideTable, sideEffects) = try await generator.loadWithSideEffects(path: context.path)
        
        context.graph = graph
        context.sideTable = sideTable
        
        logger.notice(
            sideTable.workspace.focusedTargets.isEmpty
            ? "There are no selected targets to focus on"
            : "Focused targets: \(sideTable.workspace.focusedTargets.joined(separator: ", "))"
        )
        
        // Execute side effects before hashing targets
        try sideEffectDescriptorExecutor.execute(sideEffects: sideEffects)
    }
}
