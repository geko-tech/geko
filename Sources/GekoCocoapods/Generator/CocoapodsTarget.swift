import ProjectDescription

public enum CocoapodsTargetType {
    case framework
    case test
    case app
}

public enum CocoapodsPrecompiledTarget: Equatable {
    case xcframework(path: AbsolutePath, condition: PlatformCondition? = nil)
    case framework(path: AbsolutePath, condition: PlatformCondition? = nil)
    case bundle(path: AbsolutePath, condition: PlatformCondition? = nil)
    case library(path: AbsolutePath, condition: PlatformCondition? = nil)
}
