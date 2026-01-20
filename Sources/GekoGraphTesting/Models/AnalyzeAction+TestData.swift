import Foundation
import ProjectDescription
@testable import GekoGraph

extension AnalyzeAction {
    public static func test(configurationName: String = "Beta Release") -> AnalyzeAction {
        AnalyzeAction(configuration: .configuration(configurationName))
    }
}
