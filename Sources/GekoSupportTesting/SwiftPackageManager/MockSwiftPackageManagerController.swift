import ProjectDescription
@testable import GekoSupport

public final class MockSwiftPackageManagerController: SwiftPackageManagerControlling {
    public init() {}

    public var invokedResolve = false
    public var resolveStub: ((AbsolutePath, [String], Bool) throws -> Void)?
    public func resolve(at path: AbsolutePath, arguments: [String], printOutput: Bool) throws {
        invokedResolve = true
        try resolveStub?(path, arguments, printOutput)
    }

    public var invokedUpdate = false
    public var updateStub: ((AbsolutePath, [String], Bool) throws -> Void)?
    public func update(at path: AbsolutePath, arguments: [String], printOutput: Bool) throws {
        invokedUpdate = true
        try updateStub?(path, arguments, printOutput)
    }

    public var invokedSetToolsVersion = false
    public var setToolsVersionStub: ((AbsolutePath, Version) throws -> Void)?
    public func setToolsVersion(at path: AbsolutePath, to version: Version) throws {
        invokedSetToolsVersion = true
        try setToolsVersionStub?(path, version)
    }

    public var invokedGetToolsVersion = false
    public var getToolsVersionStub: ((AbsolutePath) throws -> Version)?
    public func getToolsVersion(at path: AbsolutePath) throws -> Version {
        invokedGetToolsVersion = true
        return try getToolsVersionStub?(path) ?? Version("5.4.0")
    }

    public var invokedGetManifestAPIPath = false
    public var getManifestAPIPathStub: (() throws -> AbsolutePath)?
    public func getManifestAPIPath() throws -> AbsolutePath {
        invokedGetManifestAPIPath = true
        return try getManifestAPIPathStub?() ?? AbsolutePath(validating: "/usr/lib/swift/pm/ManifestAPI")
    }

    public var invokedLoadPackageInfo = false
    public var loadPackageInfoStub: ((AbsolutePath) throws -> PackageInfo)?
    public func loadPackageInfo(at path: AbsolutePath) throws -> PackageInfo {
        invokedLoadPackageInfo = true
        return try loadPackageInfoStub?(path)
            ?? .init(
                name: "",
                products: [],
                targets: [],
                platforms: [],
                cLanguageStandard: nil,
                cxxLanguageStandard: nil,
                swiftLanguageVersions: nil,
                toolsVersion: Version(5, 9, 0)
            )
    }

#if os(macOS)
    public var invokedBuildFatReleaseBinary = false
    public var loadBuildFatReleaseBinaryStub: ((AbsolutePath, String, AbsolutePath, AbsolutePath) throws -> Void)?
    public func buildFatReleaseBinary(
        packagePath: AbsolutePath,
        product: String,
        buildPath: AbsolutePath,
        outputPath: AbsolutePath
    ) throws {
        invokedBuildFatReleaseBinary = true
        try loadBuildFatReleaseBinaryStub?(
            packagePath,
            product,
            buildPath,
            outputPath
        )
    }
#else
    public var invokedBuildReleaseBinary = false
    public var loadBuildReleaseBinaryStub: ((PluginBinaryArch, AbsolutePath, String, AbsolutePath, AbsolutePath) throws -> Void)?
    public func buildReleaseBinary(
        for arch: PluginBinaryArch,
        packagePath: AbsolutePath,
        product: String,
        buildPath: AbsolutePath,
        outputPath: AbsolutePath
    ) throws {
        invokedBuildReleaseBinary = true
        try loadBuildReleaseBinaryStub?(
            arch,
            packagePath,
            product,
            buildPath,
            outputPath
        )
    }

    public var invokedBuildLibrary = false
    public var loadBuildLibraryStub: ((PluginBinaryArch, AbsolutePath, String, String, Bool, AbsolutePath, AbsolutePath) throws -> Void)?

    public func buildLibrary(
        for arch: PluginBinaryArch,
        packagePath: AbsolutePath,
        product: String,
        configuration: String,
        isDynamic: Bool,
        buildPath: AbsolutePath,
        outputPath: AbsolutePath
    ) throws {
        invokedBuildLibrary = true
        try loadBuildLibraryStub?(
            arch,
            packagePath,
            product,
            configuration,
            isDynamic,
            buildPath,
            outputPath
        )
    }
#endif
}
