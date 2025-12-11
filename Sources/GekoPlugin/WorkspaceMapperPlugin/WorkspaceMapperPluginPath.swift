import Foundation
import ProjectDescription

public struct WorkspaceMapperPluginPath: Equatable, Hashable {
    public let name: String
    public let path: AbsolutePath
    public let info: PluginInfo

    public init(
        name: String,
        path: AbsolutePath,
        info: PluginInfo
    ) {
        self.name = name
        self.path = path
        self.info = info
    }
}
