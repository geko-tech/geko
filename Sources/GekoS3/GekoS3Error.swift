import Foundation

public enum GekoS3Error: Swift.Error {
    case invalidaURL
    case invalideResponse
    case invalidUploadId
    case invalideSize
    case failed(statusCode: Int)
    case s3Error(S3Error)
    case multipartUpload(Swift.Error, [CompleteMultipartUpload.Part])
}

