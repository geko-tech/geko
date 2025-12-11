#if canImport(FoundationXML)
import FoundationXML
#endif
import Foundation

extension S3Error: XMLDecodable {

    static func fromXML(_ element: XMLElement) throws -> S3Error {
        S3Error(
            code: element.children?.first { $0.name == "Code" }?.stringValue,
            resource: element.children?.first { $0.name == "Resource" }?.stringValue,
            message: element.children?.first { $0.name == "Message" }?.stringValue,
            requestId: element.children?.first { $0.name == "RequestId" }?.stringValue
        )
    }
}

extension InitiateMultipartUploadResult: XMLDecodable {

    static func fromXML(_ element: XMLElement) throws -> InitiateMultipartUploadResult {
        InitiateMultipartUploadResult(
            uploadId: element.children?.first(where: { $0.name == "UploadId"})?.stringValue
        )
    }
}

extension Bucket: XMLDecodable {

    static func fromXML(_ element: XMLElement) throws -> Bucket {
        Bucket(
            name: element.children?.first(where: { $0.name == "Name"})?.stringValue
        )
    }
}

extension ListAllMyBucketsResult: XMLDecodable {

    static func fromXML(_ element: XMLElement) throws -> ListAllMyBucketsResult {
        let buckets = element.children?.first(where: { $0.name == "Buckets"})?.children?
            .compactMap { node -> Bucket? in
                guard let element = node as? XMLElement,
                      let bucket = try? Bucket.fromXML(element)
                else { return nil }
                return bucket
            }
        return ListAllMyBucketsResult(
            buckets: buckets ?? [],
            continuationToken: element.children?.first(where: { $0.name == "ContinuationToken"})?.stringValue,
            prefix: element.children?.first(where: { $0.name == "Prefix"})?.stringValue
        )
    }
}

extension ListBucketResult.Content: XMLDecodable {

    static func fromXML(_ element: XMLElement) throws -> ListBucketResult.Content {
        ListBucketResult.Content(
            key: element.children?.first(where: { $0.name == "Key" })?.stringValue,
            eTag: element.children?.first(where: { $0.name == "ETag" })?.stringValue,
            size: element.children?.first(where: { $0.name == "Size" })?.stringValue.flatMap(Int.init)
        )
    }
}

extension ListBucketResult: XMLDecodable {

    static func fromXML(_ element: XMLElement) throws -> ListBucketResult {
        let contents = element.children?.filter { $0.name == "Contents" }
            .compactMap { node -> ListBucketResult.Content? in
                guard let element = node as? XMLElement,
                      let content = try? ListBucketResult.Content.fromXML(element)
                else { return nil }
                return content
            }
        return ListBucketResult(
            contents: contents ?? [],
            isTruncated: element.children?.first(where: { $0.name == "IsTruncated"})?.stringValue.flatMap(Bool.init),
            name: element.children?.first(where: { $0.name == "Name"})?.stringValue,
            prefix: element.children?.first(where: { $0.name == "Prefix"})?.stringValue,
            delimiter: element.children?.first(where: { $0.name == "Delimiter"})?.stringValue,
            maxKeys: element.children?.first(where: { $0.name == "MaxKeys"})?.stringValue.flatMap(Int.init),
            keyCount: element.children?.first(where: { $0.name == "KeyCount"})?.stringValue.flatMap(Int.init),
            continuationToken: element.children?.first(where: { $0.name == "ContinuationToken"})?.stringValue,
            nextContinuationToken: element.children?.first(where: { $0.name == "NextContinuationToken"})?.stringValue
        )
    }
}
