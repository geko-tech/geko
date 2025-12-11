import Foundation

public final class CacheGraphLintingTask: CacheTask {
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - CacheTask
    
    public func run(context: inout CacheContext) async throws {
        guard let graph = context.graph else {
            throw CacheTaskError.cacheContextValueUninitialized
        }
        
        let linter = CacheGraphLinter()
        linter.lint(graph: graph, cacheProfile: context.cacheProfile)
    }
}
