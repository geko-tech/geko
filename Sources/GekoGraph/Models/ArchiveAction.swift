import Foundation
import ProjectDescription

public typealias ArchiveAction = ProjectDescription.ArchiveAction

extension ArchiveAction {
    public var configurationName: String {
        configuration.rawValue
    }
}
