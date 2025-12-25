import Foundation
import ProjectDescription

public struct ExecutablePluginGeko: Equatable, Hashable {
    public let name: String
    public let executablePaths: [ExecutablePath]

    public init(name: String, executablePaths: [ExecutablePath]) {
        self.name = name
        self.executablePaths = executablePaths
    }
}

public struct ExecutablePath: Equatable, Hashable {
    public let name: String
    public let path: AbsolutePath

    public init(name: String, path: AbsolutePath) {
        self.name = name
        self.path = path
    }
}
