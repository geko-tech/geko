import Foundation
import struct ProjectDescription.AbsolutePath

/// A plugin which is loaded & editable as part of the `geko edit` command.
struct EditablePluginManifest {
    enum Location {
        case local
        case remote
    }
    
    let name: String
    let path: AbsolutePath
    let location: Location
}

extension EditablePluginManifest: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.path == rhs.path
    }
}
