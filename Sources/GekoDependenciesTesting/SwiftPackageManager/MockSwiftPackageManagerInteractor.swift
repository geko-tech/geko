import ProjectDescription
import GekoCore
import GekoGraph

@testable import GekoDependencies

public final class MockSwiftPackageManagerInteractor: SwiftPackageManagerInteracting {
    public init() {}

    var invokedInstall = false
    var installStub: (
        (
            PackagePathAndSettings,
            AbsolutePath,
            [String],
            Bool,
            Version?
        ) throws -> GekoCore.DependenciesGraph
    )?

    public func install(
        packagePathAndSettings: PackagePathAndSettings,
        dependenciesDirectory: AbsolutePath,
        arguments: [String],
        shouldUpdate: Bool,
        swiftToolsVersion: Version?
    ) throws -> GekoCore.DependenciesGraph {
        invokedInstall = true
        return try installStub?(packagePathAndSettings, dependenciesDirectory, arguments, shouldUpdate, swiftToolsVersion) ?? .none
    }

    var invokedClean = false
    var cleanStub: ((AbsolutePath) throws -> Void)?

    public func clean(at path: AbsolutePath) throws {
        invokedClean = true
        try cleanStub?(path)
    }
    
    var invokedNeedFetch = false
    var needFetchResult: Bool!

    public func needFetch(path: ProjectDescription.AbsolutePath, packagePath: AbsolutePath) throws -> Bool {
        invokedNeedFetch = true
        return needFetchResult
    }
}
