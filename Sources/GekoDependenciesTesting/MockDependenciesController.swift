import ProjectDescription
import GekoCore
import GekoGraph

@testable import GekoDependencies

public final class MockDependenciesController: DependenciesControlling {
    public init() {}
  
    public var invokedFetch = false
    public var fetchStub: (
      (AbsolutePath, Config, [String], CocoapodsDependencies?, PackageSettings?, Bool, Bool) throws -> DependenciesGraph
    )?
    public func fetch(
        at path: ProjectDescription.AbsolutePath,
        config: ProjectDescription.Config,
        passthroughArguments: [String],
        cocoapodsDependencies: ProjectDescription.CocoapodsDependencies?,
        packageSettings: ProjectDescription.PackageSettings?,
        repoUpdate: Bool,
        deployment: Bool
    ) async throws -> ProjectDescription.DependenciesGraph {
        invokedFetch = true
        return try fetchStub?(path, config, passthroughArguments, cocoapodsDependencies, packageSettings, repoUpdate, deployment) ?? .none
    }
    
    public var invokedUpdate = false
    public var updateStub: (
        (AbsolutePath, Config, [String], CocoapodsDependencies?, PackageSettings?) throws -> DependenciesGraph
    )?
    public func update(
        at path: ProjectDescription.AbsolutePath,
        config: ProjectDescription.Config,
        passthroughArguments: [String],
        cocoapodsDependencies: ProjectDescription.CocoapodsDependencies?,
        packageSettings: PackageSettings?
    ) async throws -> ProjectDescription.DependenciesGraph {
        invokedUpdate = true
        return try updateStub?(path, config, passthroughArguments, cocoapodsDependencies, packageSettings) ?? .none
    }
    
    public var invokedNeedFetch = false
    public var needFetchStub: (
        (CocoapodsDependencies?, PackageSettings?, AbsolutePath, Bool) throws -> Bool
    )?
    public func needFetch(
        cocoapodsDependencies: ProjectDescription.CocoapodsDependencies?,
        packageSettings: ProjectDescription.PackageSettings?,
        path: ProjectDescription.AbsolutePath,
        cache: Bool
    ) throws -> Bool {
        invokedNeedFetch = true
        return try needFetchStub?(cocoapodsDependencies, packageSettings, path, cache) ?? false
    }

    public var invokedSave = false
    public var saveStub: ((GekoGraph.DependenciesGraph, AbsolutePath) throws -> Void)?

    public func save(dependenciesGraph: GekoGraph.DependenciesGraph, to path: AbsolutePath) throws {
        invokedSave = true
        try saveStub?(dependenciesGraph, path)
    }
}
