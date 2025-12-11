import Foundation
import ProjectDescription

public final class RetryingFileClient: FileClienting {
    private let fileClienting: FileClienting
    
    public init(fileClienting: FileClienting) {
        self.fileClienting = fileClienting
    }
    
    public func checkIfUrlIsReachable(_ url: URL) async throws -> Bool {
        try await fileClienting.checkIfUrlIsReachable(url)
    }
    
    public func upload(file: AbsolutePath, hash: String, to url: URL) async throws -> Bool {
        try await fileClienting.upload(file: file, hash: hash, to: url)
    }
    
    public func download(url: URL) async throws -> AbsolutePath {
        try await retry(url: url) {
            try await fileClienting.download(url: url)
        }
    }
    
    public func download(url: URL, etag: String?) async throws -> FileClientEtagResponse {
        try await retry(url: url) {
            try await fileClienting.download(url: url, etag: etag)
        }
    }
    
    // MARK: - Private
    
    private func retry<T>(
        url: URL,
        retries: Int = 3,
        _ work: () async throws -> T
    ) async throws -> T {
        do {
            return try await work()
        } catch let FileClientError.notFoundError(request) {
            throw FileClientError.notFoundError(request)
        } catch let FileClientError.forbiddenError(request) {
            throw FileClientError.forbiddenError(request)
        } catch {
            if retries == 0 {
                throw error
            }
            logger.warning("Failed to download \(url), Retrying…")
            return try await retry(url: url, retries: retries - 1, work)
        }
    }
}
