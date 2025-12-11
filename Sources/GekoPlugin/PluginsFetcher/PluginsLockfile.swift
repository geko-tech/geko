import Foundation

public struct PluginsLockfile: Codable {
    public struct PluginMetadata: Codable, Equatable {
        public let name: String
        public let url: String
        public let hash: String

        public init(name: String, url: String, hash: String) {
            self.name = name
            self.url = url
            self.hash = hash
        }

        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<PluginsLockfile.PluginMetadata.CodingKeys> = try decoder.container(keyedBy: PluginsLockfile.PluginMetadata.CodingKeys.self)
            self.name = try container.decode(String.self, forKey: PluginsLockfile.PluginMetadata.CodingKeys.name)
            self.url = try container.decode(String.self, forKey: PluginsLockfile.PluginMetadata.CodingKeys.url)
            self.hash = try container.decode(String.self, forKey: PluginsLockfile.PluginMetadata.CodingKeys.hash)
        }
    }

    public var pluginsMetadata: [PluginMetadata]

    public init(pluginsMetadata: [PluginMetadata]) {
        self.pluginsMetadata = pluginsMetadata
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pluginsMetadata = try container.decode([PluginsLockfile.PluginMetadata].self, forKey: .pluginsMetadata)
    }
}
