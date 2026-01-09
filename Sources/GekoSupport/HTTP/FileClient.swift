import Foundation
import ProjectDescription
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum FileClientError: LocalizedError, FatalError {
    case urlSessionError(URLRequest, Error, AbsolutePath?)
    case serverSideError(URLRequest, HTTPURLResponse, AbsolutePath?)
    case invalidResponse(URLRequest, AbsolutePath?)
    case noLocalURL(URLRequest)
    case forbiddenError(URLRequest)
    case notFoundError(URLRequest)

    // MARK: - FatalError

    public var description: String {
        switch self {
        case let .urlSessionError(request, error, path):
            return "Received a session error\(pathSubstring(path)) when performing \(request.descriptionForError): \(error.localizedDescription)"
        case let .invalidResponse(request, path):
            return "Received unexpected response from the network when performing \(request.descriptionForError)\(pathSubstring(path))"
        case let .serverSideError(request, response, path):
            return "Received error \(response.statusCode) when performing \(request.descriptionForError)\(pathSubstring(path))"
        case let .noLocalURL(request):
            return "Could not locate on disk the downloaded file after performing \(request.descriptionForError)"
        case let .forbiddenError(request):
#if canImport(FoundationNetworking)
            return "Resource requested at \(request.url?.path ?? "") is forbidden"
#else
            return "Resource requested at \(request.url?.path() ?? "") is forbidden"
#endif
        case let .notFoundError(request):
#if canImport(FoundationNetworking)
            return "Could not find requested resource at \(request.url?.path ?? "")"
#else
            return "Could not find requested resource at \(request.url?.path() ?? "")"
#endif
        }
    }

    public var type: ErrorType {
        switch self {
        case .urlSessionError: return .bug
        case .serverSideError: return .bug
        case .invalidResponse: return .bug
        case .noLocalURL: return .bug
        case .forbiddenError: return .abort
        case .notFoundError: return .abort
        }
    }

    private func pathSubstring(_ path: AbsolutePath?) -> String {
        guard let path else { return "" }
        return " for file at path \(path.pathString)"
    }

    // MARK: - LocalizedError

    public var errorDescription: String? { description }
}

public enum FileClientEtagResponse {
    case notChanged
    case changed(AbsolutePath, etag: String?)
}

public protocol FileClienting {
    func checkIfUrlIsReachable(_ url: URL) async throws -> Bool
    func upload(file: AbsolutePath, hash: String, to url: URL) async throws -> Bool
    func download(url: URL) async throws -> AbsolutePath
    func download(url: URL, etag: String?) async throws -> FileClientEtagResponse
}

public class FileClient: FileClienting {
    // MARK: - Attributes

    let session: URLSession
    private let successStatusCodeRange = 200 ..< 300
    private let notChangedStatusCode = 304
    private let forbiddenStatusCode = 403
    private let notFoundStatusCode = 404

    // MARK: - Init

    public convenience init() {
        self.init(session: FileClient.defaultSession())
    }

    private init(session: URLSession) {
        self.session = session
    }

    private static var requestTimeout: TimeInterval {
        Environment.shared.requestTimeout ?? 900
    }
    private static func defaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = FileClient.requestTimeout
        configuration.timeoutIntervalForResource = FileClient.requestTimeout
        configuration.httpMaximumConnectionsPerHost = ProcessInfo.processInfo.processorCount
        return URLSession(configuration: configuration)
    }

    // MARK: - Public
    
    public func checkIfUrlIsReachable(_ url: URL) async throws -> Bool {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "HEAD"
        urlRequest.timeoutInterval = 600

        do {
            let (_, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FileClientError.invalidResponse(urlRequest, nil)
            }
            return httpResponse.statusCode == 200
        } catch {
            if error is FileClientError {
                throw error
            }
            throw FileClientError.urlSessionError(urlRequest, error, nil)
        }
    }

    public func download(url: URL) async throws -> AbsolutePath {
        var request = URLRequest(url: url)
        request.timeoutInterval = FileClient.requestTimeout
        // usually we downloading archives, so no need to wrap them into gzip
        // or other compressing stream
        request.setValue("identity", forHTTPHeaderField: "accept-encoding")

        do {
            let (localUrl, response) = try await session.download(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw FileClientError.invalidResponse(request, nil)
            }
            if successStatusCodeRange.contains(response.statusCode) {
                return try AbsolutePath(validatingAbsolutePath: localUrl.path)
            } else if response.statusCode == forbiddenStatusCode {
                throw FileClientError.forbiddenError(request)
            } else if response.statusCode == notFoundStatusCode {
                throw FileClientError.notFoundError(request)
            } else {
                throw FileClientError.invalidResponse(request, nil)
            }
        } catch {
            if error is FileClientError {
                throw error
            } else {
                throw FileClientError.urlSessionError(request, error, nil)
            }
        }
    }

    public func download(url: URL, etag: String?) async throws -> FileClientEtagResponse {
        var request = URLRequest(
            url: url
        )
        if let etag {
            request.addValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (localUrl, response) = try await session.download(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw FileClientError.invalidResponse(request, nil)
            }
            if successStatusCodeRange.contains(response.statusCode) {
                let responseEtag = (response.allHeaderFields["Etag"] as? String)
                let path = try AbsolutePath(validatingAbsolutePath: localUrl.path)
                return .changed(path, etag: responseEtag)
            } else if response.statusCode == notChangedStatusCode {
                return .notChanged
            } else if response.statusCode == forbiddenStatusCode {
                throw FileClientError.forbiddenError(request)
            } else if response.statusCode == notFoundStatusCode {
                throw FileClientError.notFoundError(request)
            } else {
                throw FileClientError.invalidResponse(request, nil)
            }
        } catch {
            if error is FileClientError {
                throw error
            } else {
                throw FileClientError.urlSessionError(request, error, nil)
            }
        }
    }

    public func upload(file: AbsolutePath, hash _: String, to url: URL) async throws -> Bool {
        let fileSize = try FileHandler.shared.fileSize(path: file)
        let fileData = try Data(contentsOf: file.url)
        let request = uploadRequest(url: url, fileSize: fileSize, data: fileData)
        do {
            let (_, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw FileClientError.invalidResponse(request, file)
            }
            if successStatusCodeRange.contains(response.statusCode) {
                return true
            } else {
                throw FileClientError.serverSideError(request, response, file)
            }
        } catch {
            if error is FileClientError {
                throw error
            } else {
                throw FileClientError.urlSessionError(request, error, file)
            }
        }
    }

    // MARK: - Private

    private func uploadRequest(url: URL, fileSize: UInt64, data: Data) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/zip", forHTTPHeaderField: "Content-Type")
        request.setValue(String(fileSize), forHTTPHeaderField: "Content-Length")
        request.setValue("zip", forHTTPHeaderField: "Content-Encoding")
        request.httpBody = data
        return request
    }
}

#if canImport(FoundationNetworking)

private extension URLSession {
    func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        let cancellationState = CancellationStateMachine()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let task = downloadTask(with: request) { url, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let url, let response {
                        continuation.resume(returning: (url, response))
                        return
                    }
                    fatalError("Unexpected behaviour in URLSession")
                }
                task.resume()

                cancellationState.set(task.cancel)?.cancel()
            }
        }, onCancel: {
            cancellationState.cancel()?.cancel()
        })
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let cancellationState = CancellationStateMachine()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let data, let response {
                        continuation.resume(returning: (data, response))
                        return
                    }
                    fatalError("Unexpected behaviour in URLSession")
                }
                task.resume()

                cancellationState.set(task.cancel)?.cancel()
            }
        } onCancel: {
            cancellationState.cancel()?.cancel()
        }
    }
}

private final class CancellationStateMachine {
    enum Action {
        case cancel(() -> Void)

        func cancel() {
            if case let .cancel(closure) = self {
                closure()
            }
        }
    }

    struct State {
        var cancel: (() -> Void)?
        var isCancelled = false
    }

    private var state = State()
    let lock = NSLock()

    func cancel() -> Action? {
        lock.withLock {
            if state.isCancelled {
                return nil
            }
            state.isCancelled = true
            if let cancel = state.cancel {
                return .cancel(cancel)
            }
            return nil
        }
    }

    func set(_ cancel: @escaping () -> Void) -> Action? {
        lock.withLock {
            guard state.cancel == nil else { return .cancel(cancel) }

            if state.isCancelled {
                return .cancel(cancel)
            }

            state.cancel = cancel

            return nil
        }
    }
}

#endif
