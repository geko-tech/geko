import AnyCodable
import Foundation

protocol IErrorAnalytics {
    func error(_ error: Error)
}

final class ErrorAnalytics: IErrorAnalytics {
    
    private let logWritter: ILogWritter
    private let userInfoProvider: IUserInfoProvider
    
    init(
        logWritter: ILogWritter,
        userInfoProvider: IUserInfoProvider
    ) {
        self.logWritter = logWritter
        self.userInfoProvider = userInfoProvider
    }
    
    func error(_ error: Error) {
        let message = error.localizedDescription
        let shortedMessage = message.count > 500 ? String(message.prefix(500)) : message

        try? logWritter.write(error: LogError(errorMessage: shortedMessage, additionalInfo: baseDict()))
    }
    
    private func baseDict() -> [String: AnyCodable] {
        [
            "gekoVersion": AnyCodable(userInfoProvider.gekoVersion ?? "Unknown"),
            "version": AnyCodable(Constants.appVersion),
            "timestamp": AnyCodable(ISO8601DateFormatter().string(from: Date()))
        ]
    }
}
