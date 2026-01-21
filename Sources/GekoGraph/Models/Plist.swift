import Foundation
import ProjectDescription

// MARK: - Plist

extension Plist.Value {
    public var value: Any {
        switch self {
        case let .array(array):
            return array.map(\.value)
        case let .boolean(boolean):
            return boolean
        case let .dictionary(dictionary):
            return dictionary.mapValues { $0.value }
        case let .integer(integer):
            return integer
        case let .string(string):
            return string
        case let .real(double):
            return double
        }
    }
}

// MARK: - Dictionary (Plist.Value)

extension Dictionary where Value == Plist.Value {
    public func unwrappingValues() -> [Key: Any] {
        mapValues { $0.value }
    }
}
