import Foundation
import AnyCodable

class BaseAnalytics {
    private let userInfoProvider: IUserInfoProvider
    private let logWritter: ILogWritter

    init(
        userInfoProvider: IUserInfoProvider,
        logWritter: ILogWritter
    ) {
        self.userInfoProvider = userInfoProvider
        self.logWritter = logWritter
    }
    
    func send(analytics: LogAnalytics) {
        try? logWritter.write(analytics: LogAnalytics(
            name: analytics.name,
            info: baseDict().merging(analytics.info) { $1 }
        ))
    }
    
    private func baseDict() -> [String: AnyCodable] {
        [
            "gekoVersion": AnyCodable(userInfoProvider.gekoVersion ?? "Unknown"),
            "version": AnyCodable(Constants.appVersion),
            "timestamp": AnyCodable(ISO8601DateFormatter().string(from: Date()))
        ]
    }
}
