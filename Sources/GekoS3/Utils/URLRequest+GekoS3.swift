#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation

extension URLRequest {

    mutating func setHeaderIfMissing(_ name: String, _ value: String) {
        if allHTTPHeaderFields?[name] == nil {
            setValue(value, forHTTPHeaderField: name)
        }
    }
}

