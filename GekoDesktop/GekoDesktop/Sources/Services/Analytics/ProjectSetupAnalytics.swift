import AnyCodable
import Foundation

protocol IProjectSetupAnalytics {
    func projectDidSelected(_ projectPath: String)
}

final class ProjectSetupAnalytics: IProjectSetupAnalytics {
    
    private let baseAnalytics: BaseAnalytics
    
    init(baseAnalytics: BaseAnalytics) {
        self.baseAnalytics = baseAnalytics
    }

    func projectDidSelected(_ projectPath: String) {
        baseAnalytics.send(analytics: LogAnalytics(name: "projectPath", info: ["projectPath": AnyCodable(projectPath)]))
    }
}
