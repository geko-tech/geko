import Foundation
import AnyCodable
import Foundation

protocol ICacheDurationAnalytics {
    func cacheDidLoaded(_ duration: String)
}

final class WorkspaceLoadDurationAnalytics: ICacheDurationAnalytics {
    
    private let baseAnalytics: BaseAnalytics
    
    init(baseAnalytics: BaseAnalytics) {
        self.baseAnalytics = baseAnalytics
    }

    func cacheDidLoaded(_ duration: String) {
        baseAnalytics.send(analytics: LogAnalytics(name: "workspaceLoadingDuration", info: [
            "workspaceLoadingDuration": AnyCodable(duration)
        ]))
    }
}
