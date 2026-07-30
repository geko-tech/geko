import Foundation
import GekoCloud
import ProjectDescription

public final class AWSS3ServiceMock: AWSS3Servicing {
    public var checkExistsStub: ((String) async throws -> Bool)?
    public func checkExists(key: String) async throws -> Bool {
        return try await checkExistsStub!(key)
    }
    
    public var downloadStub: ((String, String) async throws -> Void)?
    public func download(key: String, fileName: String) async throws {
        try await downloadStub!(key, fileName)
    }
    
    public var uploadStub: ((ProjectDescription.AbsolutePath, String) async throws -> Void)?
    public func upload(zipPath: ProjectDescription.AbsolutePath, key: String) async throws {
        try await uploadStub!(zipPath, key)
    }
}
