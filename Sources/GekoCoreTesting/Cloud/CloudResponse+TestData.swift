import Foundation
@testable import GekoCore

extension CloudResponse {
    static func test(status: String = "status", data: T) -> CloudResponse<T> {
        CloudResponse(status: status, data: data)
    }
}
