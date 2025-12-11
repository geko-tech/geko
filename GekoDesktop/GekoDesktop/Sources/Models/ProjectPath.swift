import Foundation

public struct ProjectPath: Codable {
    let pathString: String
    let type: PathType
}

public enum PathType: String, Codable {
    case relativeToCurrentFile
    case relativeToManifest
    case relativeToRoot
}
