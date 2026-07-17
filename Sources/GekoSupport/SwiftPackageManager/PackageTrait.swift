public struct PackageTrait: Equatable, Hashable, Codable {
    public let enabledTraits: [String]
    public let name: String
    public let description: String?

    public init(enabledTraits: [String], name: String, description: String?) {
        self.enabledTraits = enabledTraits
        self.name = name
        self.description = description
    }
}

public struct PackageDependencyTrait: Equatable, Hashable, Codable {
    public let name: String
    public let condition: Set<String>?

    public init(name: String, condition: Set<String>? = nil) {
        self.name = name
        self.condition = condition
    }

    private struct TraitCondition: Codable {
        let traits: Set<String>?
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case condition
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        condition = try container.decodeIfPresent(TraitCondition.self, forKey: .condition)?.traits
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        if let condition {
            try container.encode(TraitCondition(traits: condition), forKey: .condition)
        }
    }
}

public struct PackageDependency: Equatable, Hashable, Decodable {
    public let identity: String
    public let traits: [PackageDependencyTrait]

    public init(identity: String, traits: [PackageDependencyTrait]) {
        self.identity = identity
        self.traits = traits
    }

    private enum CodingKeys: String, CodingKey {
        case fileSystem
        case sourceControl
        case registry
        case name
    }

    private struct Dependency: Decodable {
        let identity: String
        let traits: [PackageDependencyTrait]?
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let dependency = try container.decodeIfPresent([Dependency].self, forKey: .fileSystem)?.first
            ?? container.decodeIfPresent([Dependency].self, forKey: .sourceControl)?.first
            ?? container.decodeIfPresent([Dependency].self, forKey: .registry)?.first
        {
            identity = dependency.identity
            traits = dependency.traits ?? []
        } else {
            _ = try container.decode(String.self, forKey: .name)
            identity = ""
            traits = []
        }
    }
}
