import Foundation

public protocol PubGrubDependencyProvider {
    associatedtype Pkg: Package
    associatedtype Ver: Version

    func choosePackageVersion(potentialPackages: [(Pkg, VersionSet<Ver>)]) async throws -> (Pkg, Ver?)
    func getDependencies(package: Pkg, version: Ver) async throws -> Dependencies<Pkg, Ver>
    func shouldCancel() throws
}

extension PubGrubDependencyProvider {
    public func shouldCancel() throws {}
}
