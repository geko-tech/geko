import Foundation
import GekoCloud
import struct ProjectDescription.AbsolutePath

public final class CacheLatestPathStoreMock: CacheLatestPathStoring {
    
    public var stubLatestPaths: [AbsolutePath] = []
    
    public func fetchLatest() async throws -> [AbsolutePath] {
        return stubLatestPaths
    }
    
    public var invokedStoreParamters: AbsolutePath?
    public var invokedStoreParametersList: [AbsolutePath] = []
    public func store(hashFolder: AbsolutePath) async {
        invokedStoreParamters = hashFolder
        invokedStoreParametersList.append(hashFolder)
    }
    
    public var invokedSave = false
    public var invokedSaveCount = 0
    public func save() {
        invokedSave = true
        invokedSaveCount += 1
    }
}
