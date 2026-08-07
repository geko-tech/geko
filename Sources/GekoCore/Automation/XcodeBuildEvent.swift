import Foundation

public enum XcodeBuildEvent: Equatable {
    case targetCompilationStarted(targetName: String)
    case processInfoPlistFile(targetName: String)
    case targetTouched(targetName: String)
}

public enum XcodeBuildOperation: String, Equatable {
    case compileSwift = "CompileSwift"
    case compileC = "CompileC"
    case processInfoPlistFile = "ProcessInfoPlistFile"
    case touch = "Touch"
}
