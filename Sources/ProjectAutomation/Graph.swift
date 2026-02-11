import Foundation

/// The structure defining the output schema of the entire project graph.
public struct Graph: Codable, Equatable {
    /// The name of this graph.
    public let name: String

    /// The absolute path of this graph.
    public let path: String
    
    /// The workspace within this graph.
    public let workspace: Workspace

    /// The projects within this graph.
    public let projects: [String: Project]

    public init(name: String, path: String, workspace: Workspace, projects: [String: Project]) {
        self.name = name
        self.path = path
        self.workspace = workspace
        self.projects = projects
    }
}
