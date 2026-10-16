import Foundation
import ProjectDescription

public final class JSONRepository<Entity: Codable> {
    private let url: URL
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    public init(url: URL) {
        self.url = url
    }

    public func fetch() throws -> Entity {
        let data = try Data(contentsOf: url)
        return try decoder.decode(Entity.self, from: data)
    }

    public func save(_ entity: Entity) throws {
        let data = try encoder.encode(entity)
        try data.write(to: url, options: .atomic)
    }
}
