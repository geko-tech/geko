import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol DependenciesContentHashing {
    func hash(
        graphTarget: GraphTarget,
        hashedTargets: Atomic<[GraphHashedTarget: String]>,
        hashedPaths: Atomic<[AbsolutePath: String]>,
        externalDepsTree: [String: GekoGraph.DependenciesGraph.TreeDependency],
        swiftModuleCacheEnabled: Bool
    ) throws -> (String, [String: String])
}

enum DependenciesContentHasherError: FatalError, Equatable {
    case missingTargetHash(
        sourceTargetName: String,
        dependencyProjectPath: AbsolutePath,
        dependencyTargetName: String
    )
    case missingProjectTargetHash(
        sourceProjectPath: AbsolutePath,
        sourceTargetName: String,
        dependencyProjectPath: AbsolutePath,
        dependencyTargetName: String
    )

    var description: String {
        switch self {
        case let .missingTargetHash(sourceTargetName, dependencyProjectPath, dependencyTargetName):
            return "The target '\(sourceTargetName)' depends on the target '\(dependencyTargetName)' from the same project at path \(dependencyProjectPath.pathString) whose hash hasn't been previously calculated."
        case let .missingProjectTargetHash(sourceProjectPath, sourceTargetName, dependencyProjectPath, dependencyTargetName):
            return "The target '\(sourceTargetName)' from project at path \(sourceProjectPath.pathString) depends on the target '\(dependencyTargetName)' from the project at path \(dependencyProjectPath.pathString) whose hash hasn't been previously calculated."
        }
    }

    var type: ErrorType {
        switch self {
        case .missingTargetHash: return .bug
        case .missingProjectTargetHash: return .bug
        }
    }
}

/// `DependencyContentHasher`
/// is responsible for computing a hash that uniquely identifies a target dependency
public final class DependenciesContentHasher: DependenciesContentHashing {
    private let contentHasher: ContentHashing
    private let relativePathConverter: RelativePathConverting

    // MARK: - Init

    public init(
        contentHasher: ContentHashing,
        relativePathConverter: RelativePathConverting = RelativePathConverter()
    ) {
        self.contentHasher = contentHasher
        self.relativePathConverter = relativePathConverter
    }

    // MARK: - DependenciesContentHashing

    public func hash(
        graphTarget: GraphTarget,
        hashedTargets: Atomic<[GraphHashedTarget: String]>,
        hashedPaths: Atomic<[AbsolutePath: String]>,
        externalDepsTree: [String: GekoGraph.DependenciesGraph.TreeDependency],
        swiftModuleCacheEnabled: Bool
    ) throws -> (String, [String: String]) {
        let hashes = try graphTarget.target.dependencies
            .map(context: .concurrent) {
                try hash(
                    graphTarget: graphTarget,
                    dependency: $0,
                    hashedTargets: hashedTargets,
                    hashedPaths: hashedPaths,
                    externalDepsTree: externalDepsTree,
                    swiftModuleCacheEnabled: swiftModuleCacheEnabled
                )
            }
        let hashesInfo = Dictionary(hashes, uniquingKeysWith: { $1 })
        return (hashesInfo.values.sorted().compactMap { $0 }.joined(), hashesInfo)
    }

    // MARK: - Private

    private func hash(
        graphTarget: GraphTarget,
        dependency: TargetDependency,
        hashedTargets: Atomic<[GraphHashedTarget: String]>,
        hashedPaths: Atomic<[AbsolutePath: String]>,
        externalDepsTree: [String: GekoGraph.DependenciesGraph.TreeDependency],
        swiftModuleCacheEnabled: Bool
    ) throws -> (name: String, hash: String) {
        switch dependency {
        case let .target(targetName, _, _):
            guard let dependencyHash = hashedTargets.wrappedValue[GraphHashedTarget(
                projectPath: graphTarget.path,
                targetName: targetName
            )] else {
                throw DependenciesContentHasherError.missingTargetHash(
                    sourceTargetName: graphTarget.target.name,
                    dependencyProjectPath: graphTarget.path,
                    dependencyTargetName: targetName
                )
            }
            return (targetName, dependencyHash)
        case let .project(targetName, projectPath, _, _):
            guard let dependencyHash = hashedTargets.wrappedValue[GraphHashedTarget(projectPath: projectPath, targetName: targetName)] else {
                throw DependenciesContentHasherError.missingProjectTargetHash(
                    sourceProjectPath: graphTarget.path,
                    sourceTargetName: graphTarget.target.name,
                    dependencyProjectPath: projectPath,
                    dependencyTargetName: targetName
                )
            }
            return (targetName, dependencyHash)
        case let .framework(path, _, _):
            let hash = try cachedHash(path: path, hashedPaths: hashedPaths)
            return (relativePathConverter.convert(path).pathString, hash)
        case let .xcframework(path, _, _):
            let hash = try xcframeworkCachedHash(
                path: path,
                hashedPaths: hashedPaths,
                externalDepsTree: externalDepsTree,
                swiftModuleCacheEnabled: swiftModuleCacheEnabled
            )
            return (relativePathConverter.convert(path).pathString, hash)
        case let .bundle(path, _):
            let hash = try cachedHash(path: path, hashedPaths: hashedPaths)
            return (relativePathConverter.convert(path).pathString, hash)
        case let .library(path, publicHeaders, swiftModuleMap, _):
            let libraryHash = try cachedHash(path: path, hashedPaths: hashedPaths)
            let publicHeadersHash = try contentHasher.hash(path: publicHeaders)
            let hash: String
            if let swiftModuleMap {
                let swiftModuleHash = try contentHasher.hash(path: swiftModuleMap)
                hash = try contentHasher.hash("library-\(libraryHash)-\(publicHeadersHash)-\(swiftModuleHash)")
            } else {
                hash = try contentHasher.hash("library-\(libraryHash)-\(publicHeadersHash)")
            }
            return (relativePathConverter.convert(path).pathString, hash)
        case let .sdk(name, _, status, _):
            let hash = try contentHasher.hash("sdk-\(name)-\(status)")
            return (name, hash)
        case .xctest:
            return ("xctest", try contentHasher.hash("xctest"))
        case .local:
            fatalError("All references to local targets must be resolved before hashing")
        case .external:
            fatalError("All external target dependencies must be resolved before hashing!")
        }
    }

    private func cachedHash(path: AbsolutePath, hashedPaths: Atomic<[AbsolutePath: String]>) throws -> String {
        if let pathHash = hashedPaths.wrappedValue[path] {
            return pathHash
        } else {
            let pathHash = try contentHasher.hash(path: path)
            hashedPaths.modify({ value in
                value[path] = pathHash
            })
            return pathHash
        }
    }
    
    private func xcframeworkCachedHash(
        path: AbsolutePath,
        hashedPaths: Atomic<[AbsolutePath: String]>,
        externalDepsTree: [String: GekoGraph.DependenciesGraph.TreeDependency],
        swiftModuleCacheEnabled: Bool
    ) throws -> String {
        guard swiftModuleCacheEnabled else {
            return try cachedHash(path: path, hashedPaths: hashedPaths)
        }
        
        if let pathHash = hashedPaths.wrappedValue[path] {
            return pathHash
        } else {
            let name = path.basenameWithoutExt
            let pathHash: String
            if let version = externalDepsTree[name]?.version {
                pathHash = try contentHasher.hash(version)
            } else {
                pathHash = try contentHasher.hash(path: path, exclude: [{ $0.pathString.contains(".swiftmodule")}])
            }
            hashedPaths.modify({ value in
                value[path] = pathHash
            })
            return pathHash
        }
    }
}
