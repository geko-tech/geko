import Foundation
import ProjectDescription

#if !os(macOS)
/// Enum describing types of supported plugin binary architectures
public enum PluginBinaryArch: String {
    case x86_64
    case aarch64

    var targetTriple: String {
        switch self {
        case .x86_64:
            return "x86_64-unknown-linux-gnu"
        case .aarch64:
            return "aarch64-unknown-linux-gnu"
        }
    }

    var includeDir: String {
        switch self {
        case .x86_64:
            return "x86_64-linux-gnu"
        case .aarch64:
            return "aarch64-linux-gnu"
        }
    }
}
#endif

/// Protocol that defines an interface to interact with the Swift Package Manager.
public protocol SwiftPackageManagerControlling {
    /// Resolves package dependencies.
    /// - Parameters:
    ///   - path: Directory where the `Package.swift` is defined.
    ///   - printOutput: When true it prints the Swift Package Manager's output.
    func resolve(at path: AbsolutePath, arguments: [String], printOutput: Bool) throws

    /// Updates package dependencies.
    /// - Parameters:
    ///   - path: Directory where the `Package.swift` is defined.
    ///   - printOutput: When true it prints the Swift Package Manager's output.
    func update(at path: AbsolutePath, arguments: [String], printOutput: Bool) throws

    /// Gets the tools version of the package at the given path
    /// - Parameter path: Directory where the `Package.swift` is defined.
    /// - Returns: Version of tools.
    func getToolsVersion(at path: AbsolutePath) throws -> Version

    /// Gets the selected toolchain's /usr/lib/swift/pm/ManifestAPI path
    func getManifestAPIPath() throws -> AbsolutePath

    /// Sets tools version of package to the given value.
    /// - Parameter path: Directory where the `Package.swift` is defined.
    /// - Parameter version: Version of tools. When `nil` then the environment’s version will be set.
    func setToolsVersion(at path: AbsolutePath, to version: Version) throws

    /// Loads the information from the package.
    /// - Parameter path: Directory where the `Package.swift` is defined.
    func loadPackageInfo(at path: AbsolutePath) throws -> PackageInfo

#if os(macOS)
    /// Builds a release binary containing release binaries compatible with arm64 and x86.
    /// - Parameters:
    ///     - packagePath: Directory where the `Package.swift` is defined.
    ///     - product: Name of the product to be built.
    ///     - buildPath: Directory where the intermediary build products should be saved.
    ///     - outputPath: Directory where the fat binaries should be saved to.
    func buildFatReleaseBinary(
        packagePath: AbsolutePath,
        product: String,
        buildPath: AbsolutePath,
        outputPath: AbsolutePath
    ) throws
#else
    /// Builds a release binary containing release binary for desired arch.
    /// - Parameters:
    ///     - arch: Machine architecture
    ///     - packagePath: Directory where the `Package.swift` is defined.
    ///     - product: Name of the product to be built.
    ///     - buildPath: Directory where the intermediary build products should be saved.
    ///     - outputPath: Directory where the binary should be saved to.
    func buildReleaseBinary(
        for arch: PluginBinaryArch,
        packagePath: AbsolutePath,
        product: String,
        buildPath: AbsolutePath,
        outputPath: AbsolutePath
    ) throws

    /// Builds a library binary for desired arch.
    /// - Parameters:
    ///     - arch: Machine architecture
    ///     - packagePath: Directory where the `Package.swift` is defined.
    ///     - product: Name of the product to be built.
    ///     - configuration: Build configuration, usually `debug` or `release`
    ///     - isDynamic: Type of linking
    ///     - buildPath: Directory where the intermediary build products should be saved.
    ///     - outputPath: Directory where the binary should be saved to.
    func buildLibrary(
        for arch: PluginBinaryArch,
        packagePath: AbsolutePath,
        product: String,
        configuration: String,
        isDynamic: Bool,
        buildPath: AbsolutePath,
        outputPath: AbsolutePath
    ) throws
#endif
}

public final class SwiftPackageManagerController: SwiftPackageManagerControlling {
    public init() {}

    public func resolve(at path: AbsolutePath, arguments: [String], printOutput: Bool) throws {
        let command = buildSwiftPackageCommand(packagePath: path, extraArguments: arguments + ["resolve"])

        printOutput ?
            try System.shared.runAndPrint(command) :
            try System.shared.run(command)
    }

    public func update(at path: AbsolutePath, arguments: [String], printOutput: Bool) throws {
        let command = buildSwiftPackageCommand(packagePath: path, extraArguments: arguments + ["update"])

        printOutput ?
            try System.shared.runAndPrint(command) :
            try System.shared.run(command)
    }

    public func setToolsVersion(at path: AbsolutePath, to version: Version) throws {
        let extraArguments = ["tools-version", "--set", "\(version.major).\(version.minor)"]

        let command = buildSwiftPackageCommand(packagePath: path, extraArguments: extraArguments)

        try System.shared.run(command)
    }

    public func getToolsVersion(at path: AbsolutePath) throws -> Version {
        let extraArguments = ["tools-version"]

        let command = buildSwiftPackageCommand(packagePath: path, extraArguments: extraArguments)

        let rawVersion = try System.shared.capture(command).trimmingCharacters(in: .whitespacesAndNewlines)
        return try Version(versionString: rawVersion)
    }

    public func getManifestAPIPath() throws -> AbsolutePath {
        let command = [
            "swift",
            "-print-target-info"
        ]
        let rawOutput = try System.shared.capture(command).trimmingCharacters(in: .whitespacesAndNewlines)
        let json = try JSON(string: rawOutput)
        guard case let .dictionary(dict) = json,
              case let .dictionary(inner)? = dict["paths"],
              case let .string(path) = inner["runtimeResourcePath"] else { fatalError() }

        return try AbsolutePath(validating: path + "/pm/ManifestAPI")
    }

    public func loadPackageInfo(at path: AbsolutePath) throws -> PackageInfo {
        let command = buildSwiftPackageCommand(packagePath: path, extraArguments: ["dump-package"])

        let json = try System.shared.capture(command)

        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        return try decoder.decode(PackageInfo.self, from: data)
    }

    public func buildFatReleaseBinary(
        packagePath: AbsolutePath,
        product: String,
        buildPath: AbsolutePath,
        outputPath: AbsolutePath
    ) throws {
        let buildCommand: [String] = [
            "swift", "build",
            "--configuration", "release",
            "--disable-sandbox",
            "--package-path", packagePath.pathString,
            "--product", product,
            "--build-path", buildPath.pathString,
            "--triple",
        ]

        let arm64Target = "arm64-apple-macosx"
        let x64Target = "x86_64-apple-macosx"
        try System.shared.run(
            buildCommand + [
                arm64Target,
            ]
        )
        try System.shared.run(
            buildCommand + [
                x64Target,
            ]
        )

        if !FileHandler.shared.exists(outputPath) {
            try FileHandler.shared.createFolder(outputPath)
        }

        try System.shared.run([
            "lipo", "-create", "-output", outputPath.appending(component: product).pathString,
            buildPath.appending(components: arm64Target, "release", product).pathString,
            buildPath.appending(components: x64Target, "release", product).pathString,
        ])
    }

#if !os(macOS)
    public func buildReleaseBinary(
        for arch: PluginBinaryArch,
        packagePath: AbsolutePath,
        product: String,
        buildPath: AbsolutePath,
        outputPath: AbsolutePath
    ) throws {
        let buildCommand: [String] = [
            "swift", "build",
            "--configuration", "release",
            "-Xcc", "-isystem",
            "-Xcc", "/usr/include/\(arch.includeDir)",
            "--disable-sandbox",
            "--package-path", packagePath.pathString,
            "--product", product,
            "--build-path", buildPath.pathString,
            "--triple",
            arch.targetTriple
        ]

        try System.shared.run(buildCommand)

        if !FileHandler.shared.exists(outputPath) {
            try FileHandler.shared.createFolder(outputPath)
        }

        try FileHandler.shared.copy(
            from: buildPath.appending(components: arch.targetTriple, "release", product),
            to: outputPath.appending(component: product)
        )
    }

    public func buildLibrary(
        for arch: PluginBinaryArch,
        packagePath: AbsolutePath,
        product: String,
        configuration: String,
        isDynamic: Bool,
        buildPath: AbsolutePath,
        outputPath: AbsolutePath
    ) throws {
        let buildCommand: [String] = [
            "swift", "build",
            "--configuration", configuration,
            "--disable-sandbox",
            "--package-path", packagePath.pathString,
            "--product", product,
            "--build-path", buildPath.pathString,
        ]

        try System.shared.run(buildCommand)

        if !FileHandler.shared.exists(outputPath) {
            try FileHandler.shared.createFolder(outputPath)
        }

        let artifactName = isDynamic ? "lib\(product).so" : "lib\(product).a"
        try FileHandler.shared.copy(
            from: buildPath.appending(components: arch.targetTriple, configuration, artifactName),
            to: outputPath.appending(component: artifactName)
        )
    }
#endif

    // MARK: - Helpers

    private func buildSwiftPackageCommand(packagePath: AbsolutePath, extraArguments: [String]) -> [String] {
        [
            "swift",
            "package",
            "--package-path",
            packagePath.pathString,
        ]
            + extraArguments
    }
}
