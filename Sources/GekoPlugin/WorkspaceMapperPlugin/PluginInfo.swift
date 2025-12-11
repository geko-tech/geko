import Foundation

public struct PluginInfo: Codable, Hashable {
    public let projectDescriptionVersion: String
    
    public init(projectDescriptionVersion: String) {
        self.projectDescriptionVersion = projectDescriptionVersion
    }
}
