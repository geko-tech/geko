import Foundation
import ProjectDescription
@testable import GekoGraph

extension Target {
    /// Creates a Target with test data
    /// Note: Referenced paths may not exist
    public static func test(
        name: String = "Target",
        destinations: Destinations = [.iPhone, .iPad],
        product: Product = .app,
        productName: String? = nil,
        bundleId: String? = nil,
        deploymentTargets: DeploymentTargets = .iOS("13.1"),
        infoPlist: InfoPlist? = nil,
        entitlements: Entitlements? = nil,
        settings: Settings? = Settings.test(),
        sources: [SourceFiles] = [],
        resources: [ResourceFileElement] = [],
        copyFiles: [CopyFilesAction] = [],
        coreDataModels: [CoreDataModel] = [],
        headers: HeadersList? = nil,
        scripts: [TargetScript] = [],
        environmentVariables: [String: EnvironmentVariable] = [:],
        filesGroup: ProjectGroup = .group(name: "Project"),
        dependencies: [TargetDependency] = [],
        launchArguments: [LaunchArgument] = [],
        playgrounds: [AbsolutePath] = [],
        additionalFiles: [FileElement] = [],
        preCreatedFiles: [String] = [],
        mergedBinaryType: MergedBinaryType = .disabled,
        mergeable: Bool = false
    ) -> Target {
        Target(
            name: name,
            destinations: destinations,
            product: product,
            productName: productName,
            bundleId: bundleId ?? "io.geko.\(name)",
            deploymentTargets: deploymentTargets,
            infoPlist: infoPlist,
            sources: .init(sourceFiles: sources),
            playgrounds: playgrounds,
            resources: .init(resources: resources),
            copyFiles: copyFiles,
            headers: headers,
            entitlements: entitlements,
            scripts: scripts,
            dependencies: dependencies,
            settings: settings,
            coreDataModels: coreDataModels,
            environmentVariables: environmentVariables,
            launchArguments: launchArguments,
            additionalFiles: additionalFiles,
            preCreatedFiles: preCreatedFiles,
            mergedBinaryType: mergedBinaryType,
            mergeable: mergeable,
            filesGroup: filesGroup
        )
    }

    /// Creates a Target with test data
    /// Note: Referenced paths may not exist
    public static func test(
        name: String = "Target",
        platform: Platform,
        product: Product = .app,
        productName: String? = nil,
        bundleId: String? = nil,
        deploymentTarget: DeploymentTargets = .iOS("13.1"),
        infoPlist: InfoPlist? = nil,
        entitlements: Entitlements? = nil,
        settings: Settings? = Settings.test(),
        sources: [SourceFiles] = [],
        resources: [ResourceFileElement] = [],
        copyFiles: [CopyFilesAction] = [],
        coreDataModels: [CoreDataModel] = [],
        headers: HeadersList? = nil,
        scripts: [TargetScript] = [],
        environmentVariables: [String: EnvironmentVariable] = [:],
        filesGroup: ProjectGroup = .group(name: "Project"),
        dependencies: [TargetDependency] = [],
        launchArguments: [LaunchArgument] = [],
        playgrounds: [AbsolutePath] = [],
        additionalFiles: [FileElement] = [],
        mergedBinaryType: MergedBinaryType = .disabled,
        mergeable: Bool = false
    ) -> Target {
        Target(
            name: name,
            destinations: destinationsFrom(platform),
            product: product,
            productName: productName,
            bundleId: bundleId ?? "io.geko.\(name)",
            deploymentTargets: deploymentTarget,
            infoPlist: infoPlist,
            sources: .init(sourceFiles: sources),
            playgrounds: playgrounds,
            resources: .init(resources: resources),
            copyFiles: copyFiles,
            headers: headers,
            entitlements: entitlements,
            scripts: scripts,
            dependencies: dependencies,
            settings: settings,
            coreDataModels: coreDataModels,
            environmentVariables: environmentVariables,
            launchArguments: launchArguments,
            additionalFiles: additionalFiles,
            mergedBinaryType: mergedBinaryType,
            mergeable: mergeable,
            filesGroup: filesGroup
        )
    }

    /// Creates a bare bones Target with as little data as possible
    public static func empty(
        name: String = "Target",
        destinations: Destinations = [.iPhone, .iPad],
        product: Product = .app,
        productName: String? = nil,
        bundleId: String? = nil,
        deploymentTargets: DeploymentTargets = .init(),
        infoPlist: InfoPlist? = nil,
        entitlements: Entitlements? = nil,
        settings: Settings? = nil,
        sources: [SourceFiles] = [],
        resources: [ResourceFileElement] = [],
        copyFiles: [CopyFilesAction] = [],
        coreDataModels: [CoreDataModel] = [],
        headers: HeadersList? = nil,
        scripts: [TargetScript] = [],
        environmentVariables: [String: EnvironmentVariable] = [:],
        filesGroup: ProjectGroup = .group(name: "Project"),
        dependencies: [TargetDependency] = []
    ) -> Target {
        Target(
            name: name,
            destinations: destinations,
            product: product,
            productName: productName,
            bundleId: bundleId ?? "io.geko.\(name)",
            deploymentTargets: deploymentTargets,
            infoPlist: infoPlist,
            sources: .init(sourceFiles: sources),
            resources: .init(resources: resources),
            copyFiles: copyFiles,
            headers: headers,
            entitlements: entitlements,
            scripts: scripts,
            dependencies: dependencies,
            settings: settings,
            coreDataModels: coreDataModels,
            environmentVariables: environmentVariables,
            filesGroup: filesGroup
        )
    }

    // Maps a platform to a set of Destinations.  For migration purposes
    private static func destinationsFrom(_ platform: Platform) -> Destinations {
        switch platform {
        case .iOS:
            return .iOS
        case .macOS:
            return .macOS
        case .tvOS:
            return .tvOS
        case .watchOS:
            return .watchOS
        case .visionOS:
            return .visionOS
        }
    }
}
