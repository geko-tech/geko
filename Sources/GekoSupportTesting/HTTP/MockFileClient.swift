import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport

// swiftlint:disable large_tuple

public final class MockFileClient: FileClienting {
    public init() {}

    public var invokedUpload = false
    public var invokedUploadCount = 0
    public var invokedUploadParameters: (file: AbsolutePath, hash: String, url: URL)?
    public var invokedUploadParametersList = [(file: AbsolutePath, hash: String, url: URL)]()
    public var stubbedUploadResult = true
    public var stubbedUploadError: Error!

    public func upload(file: AbsolutePath, hash: String, to url: URL) async throws -> Bool {
        invokedUpload = true
        invokedUploadCount += 1
        invokedUploadParameters = (file, hash, url)
        invokedUploadParametersList.append((file, hash, url))
        if let stubbedUploadError {
            throw stubbedUploadError
        }
        return stubbedUploadResult
    }

    public var invokedDownload = false
    public var invokedDownloadCount = 0
    public var invokedDownloadParameters: (url: URL, Void)?
    public var invokedDownloadParametersList = [(url: URL, Void)]()
    public var stubbedDownloadResult: AbsolutePath!

    public func download(url: URL) async throws -> AbsolutePath {
        invokedDownload = true
        invokedDownloadCount += 1
        invokedDownloadParameters = (url, ())
        invokedDownloadParametersList.append((url, ()))
        return stubbedDownloadResult
    }

    public var stubbedDownloadEtagResult: FileClientEtagResponse!

    public func download(url _: URL, etag _: String?) async throws -> FileClientEtagResponse {
        stubbedDownloadEtagResult
    }
    
    public func checkIfUrlIsReachable(_ url: URL) async throws -> Bool {
        return false
    }
}

// swiftlint:enable large_tuple
