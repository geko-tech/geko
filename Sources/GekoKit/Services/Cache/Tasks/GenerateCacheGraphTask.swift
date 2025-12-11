import Foundation
import ProjectDescription
import GekoCache
import GekoSupport
import GekoGraph

/// Loads graph and focus modules
final class GenerateCacheGraphTask: CacheTask {
    
    // MARK: - Attributes
    
    private let generatorFactory: GeneratorFactorying
    private let noOpen: Bool
    private let opener: Opening

    // MARK: - Initialization
    
    init(
        generatorFactory: GeneratorFactorying,
        noOpen: Bool,
        opener: Opening = Opener()
    ) {
        self.generatorFactory = generatorFactory
        self.noOpen = noOpen
        self.opener = opener
    }
    
    func run(context: inout CacheContext) async throws {
        guard let graph = context.graph else {
            throw CacheTaskError.cacheContextValueUninitialized
        }
        
        let generator = try generatorFactory.default(config: context.config)
        let (workspacePath, buildGraph) = try await generator.generateGraph(graph, sideEffects: [])
        
        context.graph = buildGraph
        context.workspacePath = workspacePath
        
        if !noOpen {
            try opener.open(path: workspacePath)
        }
    }
}
