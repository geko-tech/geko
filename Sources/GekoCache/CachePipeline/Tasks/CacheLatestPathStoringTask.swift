import Foundation
import GekoCloud

public final class CacheLatestPathStoringTask: CacheTask {
    
    // MARK: - Attributes
    
    private let cacheLatestPathStore: CacheLatestPathStoring
    
    // MARK: - Initialization
    
    public init(
        cacheLatestPathStore: CacheLatestPathStoring
    ) {
        self.cacheLatestPathStore = cacheLatestPathStore
    }
    
    // MARK: - CacheTask
    
    public func run(context: inout CacheContext) async throws {
        try await cacheLatestPathStore.save()
    }
}
