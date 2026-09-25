import Foundation

public enum XcodeBuildEvent: Equatable {
    case targetCompilationStarted(targetName: String)
    case processInfoPlistFile(targetName: String)
    case targetTouched(targetName: String)
    case testCaseStarted(suite: String, testCase: String)
    case testCasePassed(suite: String, testCase: String)
    case parallelTestCasePassed(suite: String, testCase: String)
    case testCaseFailed(suite: String, testCase: String)
    case parallelTestCaseFailed(suite: String, testCase: String)
    case allTestsCompleted
}

public enum XcodeBuildOperation: String, Equatable {
    case compileSwift = "CompileSwift"
    case compileC = "CompileC"
    case processInfoPlistFile = "ProcessInfoPlistFile"
    case touch = "Touch"
}
