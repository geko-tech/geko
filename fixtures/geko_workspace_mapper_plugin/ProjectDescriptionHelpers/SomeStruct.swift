import ProjectDescription

public enum Constants {
    public static let parameterName = "parameterName"
}

public struct SomeStruct: WorkspaceMapperParameter {
    public let name: String
    public let items: [SomeStructItem]

    public init(
        name: String,
        items: [SomeStructItem]
    ) {
        self.name = name
        self.items = items
    }
}

public struct SomeStructItem: Codable {
    public let name: String
    public let str: String
    public let count: Int
    public let boolValue: Bool

    public static func generate(name: String, str: String, count: Int = 1, boolValue: Bool = false) -> SomeStructItem {
        return SomeStructItem(
            name: name,
            str: str,
            count: count,
            boolValue: boolValue
        )
    }
}