import Foundation
import ProjectDescription

public typealias AnalyzeAction = ProjectDescription.AnalyzeAction

extension AnalyzeAction {
    public var configurationName: String {
        configuration.rawValue
    }
}
