import ProjectDescription

extension Template.Attribute {
    public var isOptional: Bool {
        switch self {
        case .required:
            return false
        case .optional:
            return true
        }
    }

    public var name: String {
        switch self {
        case let .required(name):
            return name
        case let .optional(name, default: _):
            return name
        }
    }
}
