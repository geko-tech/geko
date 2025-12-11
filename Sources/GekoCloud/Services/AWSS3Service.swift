import Foundation
import GekoS3
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoSupport

/// AWS S3 Service allow to interact with files
public protocol AWSS3Servicing {
    /// - Parameters:
    ///   - zipPath: Path to zip file
    ///   - key: Path of the uploaded file on s3
    func upload(
        zipPath: AbsolutePath,
        key: String
    ) async throws
    
    /// - Parameters:
    ///    - key: Object path
    func checkExists(
        key: String
    ) async throws -> Bool
    
    /// - Parameters:
    ///    - key: Object path
    ///    - fileName: file name to save
    func download(
        key: String,
        fileName: String
    ) async throws
}

public final class AWSS3Service: AWSS3Servicing {

    // MARK: - Attributes

    private let cloudUrl: URL
    private let bucket: String
    private let gekoS3: GekoS3

    // MARK: - Initialization

    public convenience init(cloudUrl: URL, bucket: String) throws {
        self.init(
            cloudUrl: cloudUrl,
            bucket: bucket,
            credentials: try CredentialsProvider().providerCredentials(),
            verbose: Environment.shared.isVerbose
        )
    }

    public init(
        cloudUrl: URL,
        bucket: String,
        credentials: S3Credentials,
        verbose: Bool
    ) {
        self.cloudUrl = cloudUrl
        self.bucket = bucket
        self.gekoS3 = GekoS3(
            credentialsProvider: StaticCredentialsProvider(accessKey: credentials.accessKey, secretKey: credentials.secretKey),
            configuration: GekoS3Configuration(
                url: cloudUrl.absoluteString,
                concurancyLimit: ProcessInfo.processInfo.processorCount,
                multipartChunkSize: 64 * 1024 * 1024
            )
        )
    }

    // MARK: - AWSS3Servicing

    public func upload(
        zipPath: AbsolutePath,
        key: String
    ) async throws {
        try await retryOnceOnError(pathKey: key) {
            try await gekoS3.putObjectMultiparts(
                key,
                bucket: bucket,
                filename: zipPath.pathString
            )
        }
    }
    
    public func checkExists(
        key: String
    ) async throws -> Bool {
        return try await gekoS3.headObjectExist(key, bucket: bucket)
    }
    
    public func download(
        key: String,
        fileName: String
    ) async throws {
        try await gekoS3.getObjectMultiparts(
            key,
            bucket: bucket,
            filename: fileName
        )
    }
    
    // MARK: - Private
    
    private func retryOnceOnError<T>(
        pathKey: String,
        _ closure: () async throws -> T
    ) async throws -> T {
        do {
            return try await closure()
        } catch {
            logger.warning("Failed to upload \(pathKey), Retrying…")
            return try await closure()
        }
    }
}
