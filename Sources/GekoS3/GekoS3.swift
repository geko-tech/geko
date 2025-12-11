#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation

public final class GekoS3: Sendable {
    private let client: GekoS3Client
    let configuration: GekoS3Configuration

    public init(
        credentialsProvider: CredentialsProvider,
        configuration: GekoS3Configuration
    ) {
        self.configuration = configuration
        let signer = Signer(
            provider: credentialsProvider,
            region: configuration.region.rawValue
        )
        self.client = GekoS3Client(
            configuration: configuration,
            signer: signer
        )
    }

    // MARK: - Bucket operations

    public func createBucket(
        _ bucket: String
    ) async throws {
        let bucketConfiguration = CreateBucketConfiguration(
            locationConstraint: configuration.region.rawValue
        )
        let payload = XMLEncoder().encode(bucketConfiguration)
        try await client.execute(
            method: .put,
            bucket: bucket,
            bodyData: payload
        )
    }

    public func listBuckets(
        continuationToken: String? = nil,
        maxBuckets: Int? = nil,
        prefix: String? = nil
    ) async throws -> ListAllMyBucketsResult {
        var queryItems = [
            URLQueryItem(name: "bucket-region", value: configuration.region.rawValue),
            URLQueryItem(name: "prefix", value: prefix)
        ]
        if let continuationToken {
            queryItems.append(URLQueryItem(name: "continuation-token", value: continuationToken))
        }
        if let maxBuckets {
            queryItems.append(URLQueryItem(name: "max-buckets", value: "\( maxBuckets > 10000 ? 10000 : maxBuckets)"))
        }
        let (model, _) = try await client.execute(
            method: .get,
            queryItems: queryItems,
            type: ListAllMyBucketsResult.self
        )
        return model
    }

    public func headBucket(
        _ bucket: String
    ) async throws -> Bool {
        do {
            try await client.execute(
                method: .head,
                bucket: bucket
            )
        } catch {
            if case let .s3Error(s3Error) = error as? GekoS3Error,
               let code = s3Error.code,
               Self.noBucket.contains(code) {
                  return false
            }
            throw error
        }
        return true
    }

    public func deleteBucket(
        _ bucket: String
    ) async throws {
        try await client.execute(
            method: .delete,
            bucket: bucket,
            expectedStatusCode: 204
        )
    }

    public func listObjectsV2(
        bucket: String,
        continuationToken: String? = nil,
        delimiter: String?,
        prefix: String?
    ) async throws -> ListBucketResult {
        var queryItems = [
            URLQueryItem(name: "list-type", value: "2"),
            URLQueryItem(name: "delimiter", value: delimiter),
            URLQueryItem(name: "prefix", value: prefix),
        ]
        if let continuationToken {
            queryItems.append(URLQueryItem(name: "continuation-token", value: continuationToken))
        }
        let (model, _) = try await client.execute(
            method: .get,
            bucket: bucket,
            queryItems: queryItems,
            type: ListBucketResult.self
        )
        return model
    }

    // MARK: - Object operations

    public func getObject(
        _ object: String,
        bucket: String,
        offset: Int? = nil,
        length: Int? = nil
    ) async throws -> Data {
        var headers = [String: String]()
        var expectedStatusCode = 200
        if offset != nil || length != nil {
            let start = offset ?? 0
            let end = if let length {
                "\(start + length - 1)"
            } else {
                ""
            }
            headers["Range"] = "bytes=\(start)-\(end)"
            expectedStatusCode = 206
        }
        let (data, _) = try await client.execute(
            method: .get,
            bucket: bucket,
            object: object,
            headers: headers,
            expectedStatusCode: expectedStatusCode
        )
        return data
    }

    public func putObject(
        _ object: String,
        bucket: String,
        data: Data
    ) async throws {
        try await client.execute(
            method: .put,
            bucket: bucket,
            object: object,
            bodyData: data
        )
    }

    public func copyObject(
        _ object: String,
        bucket: String,
        source: String
    ) async throws {
        try await client.execute(
            method: .put,
            bucket: bucket,
            object: object,
            headers: [
                "X-Amz-Copy-Source": source
            ]
        )
    }

    public func headObject(
        _ object: String,
        bucket: String
    ) async throws -> StatObjectResult {
        let (_, response) = try await client.execute(
            method: .head,
            bucket: bucket,
            object: object
        )
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GekoS3Error.invalideResponse
        }
        let headers = httpResponse.allHeaderFields
        
        var size: Int?
        if let contentLengthString = headers["Content-Length"] as? String {
            size = Int(contentLengthString)
        }
        return StatObjectResult(
            eTag: (headers["ETag"] as? String)?.trimmingQuotes(),
            size: size
        )
    }
    
    public func headObjectExist(
        _ object: String,
        bucket: String
    ) async throws -> Bool {
        do {
            try await client.execute(
                method: .head,
                bucket: bucket,
                object: object
            )
        } catch {
            if case .s3Error = error as? GekoS3Error {
                return false
            }
            throw error
        }
        return true
    }

    public func deleteObject(
        _ object: String,
        bucket: String
    ) async throws {
        try await client.execute(
            method: .delete,
            bucket: bucket,
            object: object,
            expectedStatusCode: 204
        )
        
    }

    public func deleteObjects(
        _ objects: [String],
        bucket: String
    ) async throws {
        let delete = Delete(objects: objects.map(Delete.Object.init(key:)))
        let payload = XMLEncoder().encode(delete)
        try await client.execute(
            method: .post,
            bucket: bucket,
            queryItems: [
                URLQueryItem(name: "delete", value: nil)
            ],
            bodyData: payload
        )
    }

    // MARK: MultipartUpload

    public func сreateMultipartUpload(
        _ object: String,
        bucket: String
    ) async throws -> String {
        let (model, _) = try await client.execute(
            method: .post,
            bucket: bucket,
            object: object,
            queryItems: [
                URLQueryItem(name: "uploads", value: nil)
            ],
            type: InitiateMultipartUploadResult.self
        )
        let uploadId = model.uploadId
        if let uploadId {
            return uploadId
        }
        throw GekoS3Error.invalidUploadId
    }

    public func uploadPart(
        _ object: String,
        bucket: String,
        uploadId: String,
        data: Data,
        partNumber: Int
    ) async throws -> String? {
        let (_, response) = try await client.execute(
            method: .put,
            bucket: bucket,
            object: object,
            queryItems: [
                URLQueryItem(name: "partNumber", value: "\(partNumber)"),
                URLQueryItem(name: "uploadId", value: uploadId)
            ],
            bodyData: data
        )
        return (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")?.trimmingQuotes()
    }

    @discardableResult
    public func abortMultipartUpload(
        _ object: String,
        bucket: String,
        uploadId: String
    ) async throws -> Bool {
        try await client.execute(
            method: .delete,
            bucket: bucket,
            object: object,
            queryItems: [
                URLQueryItem(name: "uploadId", value: uploadId)
            ],
            expectedStatusCode: 204
        )
        return true
    }

    public func completedMultipartUpload(
        _ object: String,
        bucket: String,
        uploadId: String,
        parts: [CompleteMultipartUpload.Part]
    ) async throws {
        let completeMultipartUpload = CompleteMultipartUpload(parts: parts)
        let body = XMLEncoder().encode(completeMultipartUpload)
        try await client.execute(
            method: .post,
            bucket: bucket,
            object: object,
            queryItems: [
                URLQueryItem(name: "uploadId", value: uploadId)
            ],
            headers: [
                "Content-Type": "application/xml"
            ],
            bodyData: body
        )
    }

    // MARK: - Private

    private static let noBucket: Set<String> = ["NoSuchBucket", "NotFound", "Not Found"]
}
