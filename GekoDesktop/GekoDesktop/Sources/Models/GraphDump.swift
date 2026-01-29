import TSCBasic

final class GraphDump: Codable {
    let name: String
    let projects: [String: GraphProjectDump]
} 

final class GraphProjectDump: Codable {
    let name: String
    let isExternal: Bool
    let schemes: [GraphScheme]
    let targets: [GraphTargetDump]
}

final class GraphScheme: Codable {
    let name: String
    let buildAction: BuildAction?
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.buildAction = try container.decodeIfPresent(BuildAction.self, forKey: .buildAction)
    }
    
    init(name: String, buildAction: BuildAction?) {
        self.name = name
        self.buildAction = buildAction
    }
}

final class BuildAction: Codable {
    let targets: [TargetReference]
}

final class TargetReference: Codable {
    let targetName: String
    let projectPath: String?
}

final class GraphTargetDump: Codable {
    let name: String
    let product: Product
    let dependencies: [GraphTargetDependencyDump]
    
    func isExternal(_ graph: GraphDump) -> Bool {
        if let project = graph.projects.values.first(where: { $0.name == name }) {
            return project.isExternal
        } else {
            return false
        }
    }
}

enum GraphTargetDependencyDump: Equatable, Hashable, Codable {
    case target(name: String, status: LinkingStatus)
    case local(name: String, status: LinkingStatus)
    case external(name: String)
    case project(target: String, path: String, status: LinkingStatus)
    case framework(path: String, status: LinkingStatus)
    case xcframework(path: String, status: LinkingStatus)
    case library(path: String, publicHeaders: String, swiftModuleMap: String?)
    case packagePlugin(product: String)
    case packageMacro(product: String)
    case sdk(name: String, status: LinkingStatus)
    case bundle(path: String)
    case xctest
    
    var name: String {
        switch self {
        case .target(let name, _):
            name
        case .local(let name, _):
            name
        case .external(let name):
            name
        case .project( _, let path, _):
            AbsolutePath(stringLiteral: path).basenameWithoutExt
        case .framework(let path, _):
            AbsolutePath(stringLiteral: path).basenameWithoutExt
        case .xcframework(let path, _):
            AbsolutePath(stringLiteral: path).basenameWithoutExt
        case .library(let path, _, _):
            AbsolutePath(stringLiteral: path).basenameWithoutExt
        case .packagePlugin(let product):
            product
        case .packageMacro(let product):
            product
        case .sdk(let name, _):
            name
        case .bundle(let path):
            AbsolutePath(stringLiteral: path).basenameWithoutExt
        case .xctest:
            "xctest"
        }
    }
}

public enum LinkingStatus: String, Codable {
    case required
    case optional
    case none
}
