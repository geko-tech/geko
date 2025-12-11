import Foundation

public enum FatalErrorType {
    case abort
    case abortSilent
    case warning
    case warningSilent
}

protocol FatalError: Error, LocalizedError {
    var type: FatalErrorType { get }
}
