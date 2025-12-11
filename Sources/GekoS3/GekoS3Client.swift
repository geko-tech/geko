#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation
import GekoSupport

enum GekoS3RequestMethod: String {
    case head = "HEAD"
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}


final class GekoS3Client: Sendable {
    private let session: URLSession
    private let configuration: GekoS3Configuration
    private let signer: Signer
    private let scheme: String
    
    private static var requestTimeout: TimeInterval {
        Environment.shared.requestTimeout ?? 900
    }
    private static let maxSessionConnection: Int = 100

    init(
        configuration: GekoS3Configuration,
        signer: Signer
    ) {
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpMaximumConnectionsPerHost = GekoS3Client.maxSessionConnection
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        sessionConfiguration.timeoutIntervalForRequest = GekoS3Client.requestTimeout
        sessionConfiguration.timeoutIntervalForResource = GekoS3Client.requestTimeout
        self.session = URLSession(configuration: sessionConfiguration)
        self.configuration = configuration
        self.signer = signer
        self.scheme = configuration.useSSL ? "https" : "http"
    }

    @discardableResult
    func execute(
        method: GekoS3RequestMethod = .get,
        bucket: String? = nil,
        object: String? = nil,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        bodyData: Data? = nil,
        expectedStatusCode: Int = 200
    ) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        let components = buildURLComponents(
            bucket: bucket,
            object: object,
            queryItems: queryItems
        )
        let request = try await signer.signedRequest(
            method: method,
            components: components,
            headers: headers,
            body: bodyData
        )
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data, expectedStatusCode: expectedStatusCode)
        return (data, response)
    }

    @discardableResult
    func execute<T: XMLDecodable>(
        method: GekoS3RequestMethod = .get,
        bucket: String? = nil,
        object: String? = nil,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String] = [:],
        bodyData: Data? = nil,
        expectedStatusCode: Int = 200,
        type: T.Type
    ) async throws -> (T, URLResponse) {
        let (data, response) = try await execute(
            method: method,
            bucket: bucket,
            object: object,
            queryItems: queryItems,
            headers: headers,
            bodyData: bodyData,
            expectedStatusCode: expectedStatusCode
        )
        let model = try XMLDecoder().decode(data, type: T.self)
        return (model, response)
    }

    // MARK: - Private

    private func buildURLComponents(
        bucket: String?,
        object: String?,
        queryItems: [URLQueryItem]?
    ) -> URLComponents {
        var urlComponents = URLComponents()
        urlComponents.scheme = scheme
        urlComponents.host = configuration.endpoint
        urlComponents.port = configuration.port
        var pathComponents: [String] = []
        if let bucket {
            pathComponents.append(bucket)
        }
        if let object {
            pathComponents.append(object)
        }
        urlComponents.path = ("/" + pathComponents.joined(separator: "/")).replacingOccurrences(of: "//", with: "/")
        urlComponents.queryItems = queryItems
        return urlComponents
    }

    private func validateResponse(
        _ response: URLResponse,
        _ data: Data,
        expectedStatusCode: Int
    ) throws {
        guard let httpURLResponse = response as? HTTPURLResponse else {
            throw GekoS3Error.invalideResponse
        }
        if httpURLResponse.statusCode >= 400 {
            let s3rror = (try? XMLDecoder().decode(data, type: S3Error.self)) ?? S3Error()
            throw GekoS3Error.s3Error(s3rror)
        }
        if httpURLResponse.statusCode != expectedStatusCode {
            throw GekoS3Error.failed(statusCode: httpURLResponse.statusCode)
        }
    }
}
