import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

public final class CacheFrameworkBuilder: CacheArtifactBuilding {
    // MARK: - Attributes

    /// Xcode build controller instance to run xcodebuild commands.
    private let xcodeBuildController: XcodeBuildControlling

    /// Simulator controller.
    private let simulatorController: SimulatorControlling

    /// Developer's environment.
    private let developerEnvironment: DeveloperEnvironmenting

    /// Locator for getting Xcode build directory.
    private let xcodeProjectBuildDirectoryLocator: XcodeProjectBuildDirectoryLocating
    
    /// Cache framework build destinations.
    private let cacheBuildDestination: CacheFrameworkDestination

    // MARK: - Init

    /// Initialzies the builder.
    /// - Parameters:
    ///   - xcodeBuildController: Xcode build controller.
    ///   - simulatorController: Simulator controller.
    ///   - developerEnvironment: Developer environment.
    ///   - xcodeProjectBuildDirectoryLocator: Locator for Xcode builds.
    public init(
        xcodeBuildController: XcodeBuildControlling,
        destination: CacheFrameworkDestination,
        simulatorController: SimulatorControlling = SimulatorController(),
        developerEnvironment: DeveloperEnvironmenting = DeveloperEnvironment.shared,
        xcodeProjectBuildDirectoryLocator: XcodeProjectBuildDirectoryLocating = XcodeProjectBuildDirectoryLocator()
    ) {
        self.xcodeBuildController = xcodeBuildController
        self.simulatorController = simulatorController
        self.developerEnvironment = developerEnvironment
        self.xcodeProjectBuildDirectoryLocator = xcodeProjectBuildDirectoryLocator
        self.cacheBuildDestination = destination
    }

    // MARK: - ArtifactBuilding

    public func build(
        graph _: Graph,
        scheme: Scheme,
        projectTarget: XcodeBuildTarget,
        derivedDataPath: AbsolutePath?, // TODO: Rafactore this, maybe remove dd option
        rosseta: Bool,
        configuration: String,
        osVersion: Version?,
        deviceName: String?,
        into outputDirectory: AbsolutePath
    ) async throws {
        let platform = platform(scheme: scheme)

        switch cacheBuildDestination {
        case .simulator:
            try await simulatorBuild(
                projectTarget: projectTarget,
                scheme: scheme.name,
                platform: platform,
                osVersion: osVersion,
                deviceName: deviceName,
                configuration: configuration,
                derivedDataPath: outputDirectory
            )
        case .device:
            try await deviceBuild(
                projectTarget: projectTarget,
                scheme: scheme.name,
                platform: platform,
                configuration: configuration,
                derivedDataPath: outputDirectory
            )
        }

        let buildDirectory = try xcodeProjectBuildDirectoryLocator.locate(
            platform: platform,
            projectPath: projectTarget.path,
            derivedDataPath: outputDirectory,
            configuration: configuration,
            destination: cacheBuildDestination
        )

        try exportDerivedDataArtifacts(
            from: buildDirectory,
            into: outputDirectory,
            derivedDataPath: outputDirectory
        )
    }

    // MARK: - Private
    
    private func arguments(
        configuration: String
    ) async throws -> [XcodeBuildArgument] {
        return [
            .configuration(configuration),
            .xcarg("COMPILER_INDEX_STORE_ENABLE", "NO"),
            .xcarg("SWIFT_COMPILATION_MODE", "wholemodule"),
            .xcarg("GCC_GENERATE_DEBUGGING_SYMBOLS", "NO"),
            .xcarg("STRIP_INSTALLED_PRODUCT", "YES"),
            .xcarg("COPY_PHASE_STRIP", "YES"),
            .xcarg("STRIP_STYLE", "ALL"),
        ]
    }
    
    private func simulatorBuild(
        projectTarget: XcodeBuildTarget,
        scheme: String,
        platform: Platform,
        osVersion: Version?,
        deviceName: String?,
        configuration: String,
        derivedDataPath: AbsolutePath?
    ) async throws {
        var arguments = try await arguments(configuration: configuration)
        let destination = try await simulatorController
            .destination(for: platform, version: osVersion, deviceName: deviceName)
        arguments.append(.destination(destination))
        
        try xcodeBuildController.build(
            projectTarget,
            scheme: scheme,
            destination: nil,
            rosetta: false,
            derivedDataPath: derivedDataPath,
            clean: false,
            arguments: arguments
        )
    }
    
    private func deviceBuild(
        projectTarget: XcodeBuildTarget,
        scheme: String,
        platform: Platform,
        configuration: String,
        derivedDataPath: AbsolutePath?
    ) async throws {
        var arguments = try await arguments(configuration: configuration)
        arguments.append(.sdk(platform.xcodeDeviceSDK))
        
        try xcodeBuildController.build(
            projectTarget,
            scheme: scheme,
            destination: nil,
            rosetta: false,
            derivedDataPath: derivedDataPath,
            clean: false,
            arguments: arguments
        )
    }

    private func exportDerivedDataArtifacts(
        from buildDirectory: AbsolutePath,
        into outputDirectory: AbsolutePath,
        derivedDataPath: AbsolutePath
    ) throws {
        let frameworks = FileHandler.shared.glob(buildDirectory, glob: "*.framework")
        for framework in frameworks {
            try FileHandler.shared.move(from: framework, to: outputDirectory.appending(component: framework.basename))
        }

        let bundles = FileHandler.shared.glob(buildDirectory, glob: "*.bundle")
        for bundle in bundles {
            try FileHandler.shared.move(from: bundle, to: outputDirectory.appending(component: bundle.basename))
        }
        
        let dsyms = FileHandler.shared.glob(buildDirectory, glob: "*.dSYM")
        for dsym in dsyms {
            try FileHandler.shared.move(from: dsym, to: outputDirectory.appending(component: dsym.basename))
        }
    }
}
