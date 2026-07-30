import Foundation
import GekoSupport
import GekoCocoapods
import ProjectDescription

public struct RegistrySpec: Decodable {
    public let version: RegistryPackageVersion
    public let dependencies: [String: CocoapodsVersionRange]
}

extension CocoapodsVersionRange: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        self = try CocoapodsVersionRange.from(string: container.decode(String.self))
    }
}

extension CocoapodsVersionRange {
    public func toString() -> String {
        switch self {
        case .any:
            return ""
        case let .exact(version):
            return version.description
        case let .higherThan(version):
            return ">= \(version)"
        case let .strictlyLessThan(version):
            return "< \(version)"
        case let .between(lower, higher):
            return ">= \(lower) < \(higher)"
        default:
            return ""
        }
    }
}

extension CocoapodsVersionRange: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = try encoder.singleValueContainer()
        try container.encode(self.toString())
    }
}
