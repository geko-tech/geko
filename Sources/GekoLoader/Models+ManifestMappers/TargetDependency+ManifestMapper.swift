import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

// MARK: - TargetDependency Mapper Error

public enum TargetDependencyMapperError: FatalError {
    case invalidExternalDependency(name: String)

    public var type: ErrorType { .abort }

    public var description: String {
        switch self {
        case let .invalidExternalDependency(name):
            return "`\(name)` is not a valid configured external dependency"
        }
    }
}

extension TargetDependency {
    /// Maps a ProjectDescription.TargetDependency instance into a GekoGraph.TargetDependency instance.
    /// - Parameters:
    ///   - generatorPaths: Generator paths.
    ///   - externalDependencies: External dependencies graph.
    public func resolveDependencies( // swiftlint:disable:this function_body_length
        into result: inout [TargetDependency],
        externalDependencies: [String: [TargetDependency]]
    ) throws {
        switch self {
        case .target, .local, .project, .framework, .library, .xcframework, .bundle, .xctest:
            result.append(self)
        case let .sdk(name, type, status, condition):
            result.append(.sdk(
                name: "\(type.filePrefix)\(name).\(type.fileExtension)",
                type: type,
                status: status,
                condition: condition
            ))
        case let .external(name, _):
            guard let dependencies = externalDependencies[name] else {
                throw TargetDependencyMapperError.invalidExternalDependency(name: name)
            }
            result.append(contentsOf: dependencies.map { $0.withCondition($0.condition) })
        }
    }

    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        switch self {
        case let .project(target, projectPath, status, condition):
            self = .project(
                target: target,
                path: try generatorPaths.resolve(path: projectPath),
                status: status,
                condition: condition
            )
        case let .framework(frameworkPath, status, condition):
            self = .framework(
                path: try generatorPaths.resolve(path: frameworkPath),
                status: status,
                condition: condition
            )
        case let .library(libraryPath, publicHeaders, swiftModuleMap, condition):
            self = .library(
                path: try generatorPaths.resolve(path: libraryPath),
                publicHeaders: try generatorPaths.resolve(path: publicHeaders),
                swiftModuleMap: try swiftModuleMap.map { try generatorPaths.resolve(path: $0) },
                condition: condition
            )
        case let .xcframework(path, status, condition):
            self = .xcframework(
                path: try generatorPaths.resolve(path: path),
                status: status,
                condition: condition
            )
        case let .bundle(path, condition):
            self = .bundle(
                path: try generatorPaths.resolve(path: path),
                condition: condition
            )
        case .xctest, .external, .sdk, .local, .target:
            break
        }
    }
}

extension ProjectDescription.PlatformFilters {
    var asGraphFilters: ProjectDescription.PlatformFilters {
        Set<ProjectDescription.PlatformFilter>(map(\.graphPlatformFilter))
    }
}

extension ProjectDescription.PlatformCondition {
    var asGraphCondition: PlatformCondition? {
        .when(Set(platformFilters.asGraphFilters))
    }
}

extension ProjectDescription.PlatformFilter {
    fileprivate var graphPlatformFilter: ProjectDescription.PlatformFilter {
        switch self {
        case .ios:
            .ios
        case .macos:
            .macos
        case .tvos:
            .tvos
        case .catalyst:
            .catalyst
        case .driverkit:
            .driverkit
        case .watchos:
            .watchos
        case .visionos:
            .visionos
        }
    }
}

extension ProjectDescription.SDKType {
    /// The prefix associated to the type
    fileprivate var filePrefix: String {
        switch self {
        case .library:
            return "lib"
        case .framework:
            return ""
        }
    }

    /// The extension associated to the type
    fileprivate var fileExtension: String {
        switch self {
        case .library:
            return "tbd"
        case .framework:
            return "framework"
        }
    }
}
