import Foundation
import struct ProjectDescription.AbsolutePath
@testable import GekoGraph

extension AnalyzeAction {
    public static func test(configurationName: String = "Beta Release") -> AnalyzeAction {
        AnalyzeAction(configuration: .configuration(configurationName))
    }
}
