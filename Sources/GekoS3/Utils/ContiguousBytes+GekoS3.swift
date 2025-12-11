import Foundation

extension ContiguousBytes {

    func hexDigest() -> String {
        withUnsafeBytes { ptr in
            ptr.map { String(format: "%02hhx", $0) }
        }
        .joined()
    }
}
