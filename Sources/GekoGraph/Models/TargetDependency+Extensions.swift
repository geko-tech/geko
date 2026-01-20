import Foundation
import ProjectDescription

public extension TargetDependency {
    var condition: PlatformCondition? {
        switch self {
        case .target(name: _, status: _, condition: let condition):
            condition
        case .local(name: _, status: _, condition: let condition):
            condition
        case .project(target: _, path: _, status: _, condition: let condition):
            condition
        case .framework(path: _, status: _, condition: let condition):
            condition
        case .xcframework(path: _, status: _, condition: let condition):
            condition
        case .library(path: _, publicHeaders: _, swiftModuleMap: _, condition: let condition):
            condition
        case .sdk(name: _, type: _, status: _, condition: let condition):
            condition
        case .bundle(path: _, condition: let condition):
            condition
        case .external(name: _, condition: let condition):
            condition
        case .xctest: nil
        }
    }

    func withCondition(_ condition: PlatformCondition?) -> TargetDependency {
        switch self {
        case .target(name: let name, status: let status, condition: _):
            return .target(name: name, status: status, condition: condition)
        case .local(name: let name, status: let status, condition: _):
            return .local(name: name, status: status, condition: condition)
        case .project(target: let target, path: let path, status: let status, condition: _):
            return .project(target: target, path: path, status: status, condition: condition)
        case .framework(path: let path, status: let status, condition: _):
            return .framework(path: path, status: status, condition: condition)
        case .xcframework(path: let path, status: let status, condition: _):
            return .xcframework(path: path, status: status, condition: condition)
        case .library(path: let path, publicHeaders: let headers, swiftModuleMap: let moduleMap, condition: _):
            return .library(path: path, publicHeaders: headers, swiftModuleMap: moduleMap, condition: condition)
        case .sdk(name: let name, type: let type, status: let status, condition: _):
            return .sdk(name: name, type: type, status: status, condition: condition)
        case let .bundle(path, _):
            return .bundle(path: path, condition: condition)
        case .xctest: return .xctest
        case .external(name: let name, condition: _):
            return .external(name: name, condition: condition)
        }
    }
}
