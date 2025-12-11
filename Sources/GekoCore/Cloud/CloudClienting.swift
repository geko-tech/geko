import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import GekoSupport

public protocol CloudClienting {
    func request<T, E>(_ resource: HTTPResource<T, E>) async throws -> (object: T, response: HTTPURLResponse)
}
