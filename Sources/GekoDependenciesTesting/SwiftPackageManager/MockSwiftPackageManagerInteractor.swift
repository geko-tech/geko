import ProjectDescription
import GekoCore
import GekoGraph

@testable import GekoDependencies

public final class MockSwiftPackageManagerInteractor: SwiftPackageManagerInteracting {
    public init() {}

    var invokedInstall = false
    var installStub: (
        (
            AbsolutePath,
            PackageSettings,
            [String],
            Bool,
            Version?
        ) throws -> GekoCore.DependenciesGraph
    )?

    public func install(
        dependenciesDirectory: AbsolutePath,
        packageSettings: PackageSettings,
        arguments: [String],
        shouldUpdate: Bool,
        swiftToolsVersion: Version?
    ) throws -> GekoCore.DependenciesGraph {
        invokedInstall = true
        return try installStub?(dependenciesDirectory, packageSettings, arguments, shouldUpdate, swiftToolsVersion) ?? .none
    }

    var invokedClean = false
    var cleanStub: ((AbsolutePath) throws -> Void)?

    public func clean(dependenciesDirectory: AbsolutePath) throws {
        invokedClean = true
        try cleanStub?(dependenciesDirectory)
    }
    
    var invokedNeedFetch = false
    var needFetchResult: Bool!

    public func needFetch(path: ProjectDescription.AbsolutePath) throws -> Bool {
        invokedNeedFetch = true
        return needFetchResult
    }
}
