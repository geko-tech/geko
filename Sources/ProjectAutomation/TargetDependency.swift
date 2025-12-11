import Foundation

public enum LinkingStatus: String, Codable {
    case required
    case optional
    case none
}

public enum TargetDependency: Equatable, Hashable, Codable {
    case target(name: String, status: LinkingStatus)
    case local(name: String, status: LinkingStatus)
    case external(name: String)
    case project(target: String, path: String, status: LinkingStatus)
    case framework(path: String, status: LinkingStatus)
    case xcframework(path: String, status: LinkingStatus)
    case library(path: String, publicHeaders: String, swiftModuleMap: String?)
    case sdk(name: String, status: LinkingStatus)
    case bundle(path: String)
    case xctest
}
