import Foundation
import GekoSupport
import ProjectDescription

public final class AWSS3CacheCloudService: CacheCloudServicing {

    // MARK: - Attributes

    private let awsService: AWSS3Service
    private let temporaryDir: TemporaryDirectory
    
    public init(awsService: AWSS3Service) throws {
        self.awsService = awsService
        self.temporaryDir = try TemporaryDirectory(removeTreeOnDeinit: true)
    }
    
    public func cacheExists(hash: String, name: String, contextFolder: String) async throws -> Bool {
        let result = try await awsService.checkExists(
            key: objectKey(
                name: name,
                hash: hash,
                contextFolder: contextFolder
            )
        )
        return result
    }
    
    public func download(hash: String, name: String, contextFolder: String) async throws -> ProjectDescription.AbsolutePath {
        let key = objectKey(name: name, hash: hash, contextFolder: contextFolder)
        let filePath = "\(temporaryDir.path.pathString)/\(UUID().uuidString)"
        try await awsService.download(key: key, fileName: filePath)
        return AbsolutePath(stringLiteral: filePath)
    }
    
    // MARK: - Private
    
    private func objectKey(name: String, hash: String, contextFolder: String) -> String {
        return "/\(name)/\(contextFolder)/\(hash).zip"
    }
}
