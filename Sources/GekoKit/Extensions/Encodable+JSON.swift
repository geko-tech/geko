import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport

extension Encodable {
    func toJSON() throws -> JSON {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        return try JSON(data: data)
    }
}
