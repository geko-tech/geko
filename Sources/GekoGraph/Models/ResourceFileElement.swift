import Foundation
import ProjectDescription

extension ResourceFileElement {
    public var path: AbsolutePath {
        switch self {
        case let .glob(pattern, _, _, _):
            return pattern
        case let .file(path, _, _):
            return path
        case let .folderReference(path, _, _):
            return path
        }
    }

    public var isReference: Bool {
        if case .folderReference = self {
            return true
        }
        return false
    }

    public var tags: [String] {
        switch self {
        case let .glob(_, _, tags, _):
            return tags
        case let .file(_, tags, _):
            return tags
        case let .folderReference(_, tags, _):
            return tags
        }
    }

    public var inclusionCondition: PlatformCondition? {
        switch self {
        case let .glob(_, _, _, condition):
            return condition
        case let .file(_, _, condition):
            return condition
        case let .folderReference(_, _, condition):
            return condition
        }
    }

    public init(path: AbsolutePath) {
        self = .file(path: path)
    }
}

extension [ResourceFileElement] {
    public mutating func remove(path: AbsolutePath) {
        guard let index = firstIndex(of: ResourceFileElement(path: path)) else { return }
        remove(at: index)
    }
}
