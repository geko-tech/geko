import Glob

extension GlobNDFAError: FatalError {
    public var type: ErrorType {
        .abort
    }
}

extension GlobSetError: FatalError {
    public var type: ErrorType {
        .abort
    }
}
