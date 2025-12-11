import Crypto
import Foundation
import struct ProjectDescription.AbsolutePath

public struct MD5Hasher {
    private var hasher = Insecure.MD5()

    public init() {}

    public mutating func combine(_ path: borrowing AbsolutePath) {
        hasher.update(data: path.pathString.data(using: .utf8)!)
    }

    public mutating func combine(_ string: borrowing String) {
        hasher.update(data: string.data(using: .utf8)!)
    }

    public mutating func combine(_ data: borrowing Data) {
        hasher.update(data: data)
    }

    public mutating func finalize() -> String {
        hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
