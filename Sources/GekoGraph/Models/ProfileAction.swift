import Foundation
import ProjectDescription

public typealias ProfileAction = ProjectDescription.ProfileAction

extension ProfileAction {
    public var configurationName: String {
        configuration.rawValue
    }
}
