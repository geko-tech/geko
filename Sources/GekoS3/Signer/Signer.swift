#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation
import Crypto

struct SignatureContext {
    let urlComponents: URLComponents
    let method: String
    let region: String
    let accessKeyId: String
    let secretAccessKey: String
    let timestamp: String
    let date: String
    let scope: String
    let sha256content: String
    let signedHeaders: String
    let canonicalHeaders: String

    init(
        urlComponents: URLComponents,
        method: String,
        region: String,
        accessKeyId: String,
        secretAccessKey: String,
        headers: [String: String],
        timestamp: String,
        sha256content: String
    ) {
        self.urlComponents = urlComponents
        self.method = method
        self.region = region
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.timestamp = timestamp
        self.date = String(timestamp.prefix(8))
        self.scope = "\(date)/\(region)/s3/aws4_request"
        self.sha256content = sha256content

        var result = [(key: String, value: String)]()
        for header in headers {
            let lowercasedKey = header.key.lowercased()
            if Self.requiredHeaders.contains(lowercasedKey) || lowercasedKey.hasPrefix("x-amz-") {
                result.append((lowercasedKey, header.value.canonicHeaderValue))
            }
        }
        result.sort(by: { $0.key < $1.key })
        (signedHeaders, canonicalHeaders) = result.reduce(into: ("", "")) { partialResult, header in
            var signedSeparator = ";"
            if partialResult.0.isEmpty {
                signedSeparator = ""
            }
            partialResult.0 += signedSeparator + header.key
            partialResult.1 += header.key + ":" + header.value + "\n"
        }
    }

    private static let requiredHeaders: Set<String> = [
        "host",
        "content-type",
        "content-encoding",
        "content-length"
    ]
}

final class Signer: Sendable {
    private let provider: CredentialsProvider
    private let region: String
    private static let timeStampDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    init(
        provider: CredentialsProvider,
        region: String
    ) {
        self.provider = provider
        self.region = region
    }

    func signedRequest(
        method: GekoS3RequestMethod = .get,
        components: URLComponents,
        headers: [String: String] = [:],
        body: Data? = nil,
        requestDate: Date = Date()
    ) async throws -> URLRequest {
        let credentials = try await provider.retrieve()
        guard let url = components.url else {
            throw GekoS3Error.invalidaURL
        }
        
        let timestamp = Self.timeStampDateFormatter.string(from: requestDate)
        let sha256content = contentSHA256(for: body, isHttps: components.scheme == "https")

        var headers = headers
        headers["Host"] = components.netloc
        headers["X-Amz-Content-Sha256"] = sha256content
        headers["X-Amz-Date"] = timestamp
        if method == .post || method == .put {
            headers.merge([
                "Content-Type": "application/octet-stream",
                "Content-Length": "\(body?.count ?? 0)"
            ], uniquingKeysWith: { key,_ in key })
        }
        if let token = credentials.sessionToken {
            headers["X-Amz-Security-Token"] = token
        }

        let context = SignatureContext(
            urlComponents: components,
            method: method.rawValue,
            region: region,
            accessKeyId: credentials.accessKey,
            secretAccessKey: credentials.secretKey,
            headers: headers,
            timestamp: timestamp,
            sha256content: sha256content
        )

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.allHTTPHeaderFields = headers

        addAuthorization(context, to: &request)

        return request
    }

    private func contentSHA256(for data: Data?, isHttps: Bool) -> String {
        guard let data else {
            return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }
        if isHttps {
            return "UNSIGNED-PAYLOAD"
        }
        return SHA256.hash(data: data).hexDigest()
    }

    private func addAuthorization(
        _ context: SignatureContext,
        to request: inout URLRequest
    ) {
        // step 1
        let canonicalRequest = createCanonicalRequest(context)
        // step 2
        let hashedCanonicaRequest = hashCanonicalRequest(canonicalRequest: canonicalRequest)
        // step 3
        let stringToSign = stringToSign(context, hashedCanonicaRequest: hashedCanonicaRequest)
        // step 4
        let signingKey = signingKey(context)
        // step 5
        let signature = signature(stringToSign: stringToSign, signingKey: signingKey)
        // step 6
        addSignature(context, to: &request, signature: signature)
    }

    // MARK: - Step 1: Create a canonical request

    private func createCanonicalRequest(
        _ context: SignatureContext
    ) -> String {
        return context.method + "\n" +
        context.urlComponents.path.uriEncode() + "\n" +
        context.urlComponents.canonicalQueryString() + "\n" +
        context.canonicalHeaders + "\n" +
        context.signedHeaders + "\n" +
        context.sha256content
    }

    // MARK: - Step 2: Create a hash of the canonical request

    private func hashCanonicalRequest(
        canonicalRequest: String
    ) -> String {
        SHA256.hash(data: canonicalRequest.uint8).hexDigest()
    }

    // MARK: - Step 3: Create a string to sign

    private func stringToSign(
        _ context: SignatureContext,
        hashedCanonicaRequest: String
    ) -> String {
        [
            "AWS4-HMAC-SHA256",
            context.timestamp,
            context.scope,
            hashedCanonicaRequest
        ].joined(separator: "\n")
    }

    // MARK: - Step 4: Signing key

    private func signingKey(
        _ context: SignatureContext
    ) -> SymmetricKey {
        let dateKey = HMAC<SHA256>.authenticationCode(for: context.date.uint8, using: SymmetricKey(data: "AWS4\(context.secretAccessKey)".uint8))
        let dateRegionKey = HMAC<SHA256>.authenticationCode(for: context.region.uint8, using: SymmetricKey(data: dateKey))
        let dateRegionServiceKey = HMAC<SHA256>.authenticationCode(for: "s3".uint8, using: SymmetricKey(data: dateRegionKey))
        let signingKey = HMAC<SHA256>.authenticationCode(for: "aws4_request".uint8, using: SymmetricKey(data: dateRegionServiceKey))
        return SymmetricKey(data: signingKey)
    }

    // MARK: - Step 5: Calculate the signature

    private func signature(
        stringToSign: String,
        signingKey: SymmetricKey
    ) -> String {
        HMAC<SHA256>.authenticationCode(for: stringToSign.uint8, using: signingKey).hexDigest()
    }

    // MARK: - Step 6: Add the signature to the request

    private func addSignature(
        _ context: SignatureContext,
        to request: inout URLRequest,
        signature: String
    ) {
        let authorization = [
            "AWS4-HMAC-SHA256 Credential=\(context.accessKeyId)/\(context.scope)",
            "SignedHeaders=\(context.signedHeaders)",
            "Signature=\(signature)"
        ].joined(separator: ", ")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }
}
