import Foundation
import ProjectDescription

public typealias RunAction = ProjectDescription.RunAction

extension RunAction {
    public var configurationName: String {
        configuration.rawValue
    }
}
