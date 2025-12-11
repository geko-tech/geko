import Foundation

struct LocalizedAlertError: LocalizedError {
    // MARK: - Attributes
    
    var localizedDescription: String
    var actionButtonTitle: String
    var additionalInfo: String
    var rawDescription: String
    
    var errorDescription: String?  {
        localizedDescription
    }
    
    // MARK: - Initialization

    init(
        error: Error,
        actionButtonTitle: String = "OK",
        additionalInfo: String = "You can create issue \(Constants.issuesURL)"
    ) {
        
        let rawDescription: String
        if let localizedError = error as? LocalizedError, let decription = localizedError.errorDescription {
            rawDescription = decription
        } else {
            rawDescription = error.localizedDescription
        }
        self.localizedDescription = rawDescription.count > 1000 ? String(rawDescription.prefix(1000)) : rawDescription
        self.rawDescription = rawDescription
        self.actionButtonTitle = actionButtonTitle
        self.additionalInfo = additionalInfo
    }
}

protocol IApplicationErrorHandler: AnyObject {

    @MainActor
    func handle(_ error: Error, additionalInfo: String)
    @MainActor
    func handle(_ error: Error)
    func setDelegate(_ delegate: IApplicationErrorHandlerDelegate)
}

@MainActor
protocol IApplicationErrorHandlerDelegate: AnyObject {
    
    func showAlert(_ error: LocalizedAlertError)
}

final class ApplicationErrorHandler: IApplicationErrorHandler {
    // MARK: - Attributes
    
    private let logger: ILogger
    private let errorAnalytics: IErrorAnalytics
    
    private weak var delegate: IApplicationErrorHandlerDelegate?
    
    // MARK: - Initialization
    
    init(
        logger: ILogger,
        errorAnalytics: IErrorAnalytics
    ) {
        self.logger = logger
        self.errorAnalytics = errorAnalytics
    }
    
    // MARK: - IApplicationErrorHandler
    
    @MainActor
    func handle(_ error: Error) {
        handle(error, additionalInfo: "")
    }
    
    @MainActor 
    func handle(_ error: Error, additionalInfo: String) {
        let localizedError = LocalizedAlertError(error: error)
        if let fatalError = error as? FatalError {
            switch fatalError.type {
            case .abort, .warning:
                delegate?.showAlert(localizedError)
                errorAnalytics.error(error)
                logToFile(error, additionalInfo: additionalInfo)
            case .abortSilent, .warningSilent:
                logger.log(.warning, info: error.localizedDescription)
            }
        } else {
            delegate?.showAlert(localizedError)
        }
    }
    
    func setDelegate(_ delegate: IApplicationErrorHandlerDelegate) {
        if self.delegate != nil {
            logger.log(.debug, info: "The error handling delegate was previously installed. At the moment you should only have 1 delegate\r\n")
        }
        self.delegate = delegate
    }
}

// MARK: - Private Helpers

private extension ApplicationErrorHandler {
    
    func logToFile(_ error: Error, additionalInfo: String) {
        Task {
            let additionalInfo = [
                "Error Description:": error.localizedDescription,
                "Additional info for dev:": additionalInfo
            ]
            logger.log(.critical, info: error.localizedDescription, additionalInfo: additionalInfo)
        }
    }
}
