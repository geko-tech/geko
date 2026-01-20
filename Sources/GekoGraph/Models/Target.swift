import Foundation
import ProjectDescription

// swiftlint:disable:next type_body_length
public extension Target {
    // MARK: - Static

    // Note: The `.docc` file type is technically both a valid source extension and folder extension
    //       in order to compile the documentation archive (including Tutorials, Articles, etc.)
    static let validSourceExtensions: [String] = [
        "m", "swift", "mm", "cpp", "cc", "c", "d", "s", "intentdefinition", "xcmappingmodel", "metal", "mlmodel", "docc",
        "playground", "rcproject", "mlpackage",
    ]
    static let validHeaderExtensions: [String] = [
        "h"
    ]
    static let validFolderExtensions: [String] = [
        "framework", "bundle", "app", "xcassets", "appiconset", "scnassets",
    ]

    /// Target can be included in the link phase of other targets
    func isLinkable() -> Bool {
        [.dynamicLibrary, .staticLibrary, .framework, .staticFramework].contains(product)
    }

    /// Returns whether a target is exclusive to a single platform
    func isExclusiveTo(_ platform: Platform) -> Bool {
        destinations.allSatisfy { $0.platform == platform }
    }

    /// Returns whether a target supports a platform
    func supports(_ platform: Platform) -> Bool {
        destinations.contains(where: { $0.platform == platform })
    }

    /// List of platforms this target deploys to
    var supportedPlatforms: Set<Platform> {
        Set(destinations.map { $0.platform })
    }

    /// Returns target's pre scripts.
    var preScripts: [TargetScript] {
        scripts.filter { $0.order == .pre }
    }

    /// Returns target's post scripts.
    var postScripts: [TargetScript] {
        scripts.filter { $0.order == .post }
    }

    /// Returns true if the target supports Mac Catalyst
    var supportsCatalyst: Bool {
        destinations.contains(.macCatalyst)
    }

    /// Target can link static products (e.g. an app can link a staticLibrary)
    func canLinkStaticProducts() -> Bool {
        [
            .framework,
            .app,
            .commandLineTool,
            .xpc,
            .unitTests,
            .uiTests,
            .appExtension,
            .watch2Extension,
            .messagesExtension,
            .appClip,
            .tvTopShelfExtension,
            .systemExtension,
            .extensionKitExtension,
            .macro,
        ].contains(product)
    }

    /// Returns true if the target supports having a headers build phase..
    var shouldIncludeHeadersBuildPhase: Bool {
        switch product {
        case .framework, .staticFramework, .staticLibrary, .dynamicLibrary:
            return true
        default:
            return false
        }
    }

    /// Returns true if the target supports having sources.
    var supportsSources: Bool {
        switch product {
        case .stickerPackExtension, .watch2App:
            return false
        case .bundle:
            // Bundles only support source when targetting macOS only
            return isExclusiveTo(.macOS)
        default:
            return true
        }
    }

    /// Returns true if the target deploys to more then one platform
    var isMultiplatform: Bool {
        supportedPlatforms.count > 1
    }

    /// Returns true if the target supports hosting resources
    var supportsResources: Bool {
        switch product {
        case .app,
            .framework,
            .unitTests,
            .uiTests,
            .bundle,
            .appExtension,
            .watch2App,
            .watch2Extension,
            .tvTopShelfExtension,
            .messagesExtension,
            .stickerPackExtension,
            .appClip,
            .systemExtension,
            .extensionKitExtension:
            return true

        case .commandLineTool,
            .macro,
            .dynamicLibrary,
            .staticLibrary,
            .staticFramework,
            .xpc,
            .aggregateTarget:
            return false
        }
    }

    var legacyPlatform: Platform {
        destinations.first?.platform ?? .iOS
    }

    /// Returns true if the target is an AppClip
    var isAppClip: Bool {
        if case .appClip = product {
            return true
        }
        return false
    }

    /// Determines if the target is an embeddable watch application
    /// i.e. a product that can be bundled with a host iOS application
    func isEmbeddableWatchApplication() -> Bool {
        let isWatchOS = isExclusiveTo(.watchOS)
        let isApp = (product == .watch2App || product == .app)
        return isWatchOS && isApp
    }

    /// Determines if the target is an embeddable xpc service
    /// i.e. a product that can be bundled with a host macOS application
    func isEmbeddableXPCService() -> Bool {
        product == .xpc
    }

    /// Determines if the target is an embeddable system extension
    /// i.e. a product that can be bundled with a host macOS application
    func isEmbeddableSystemExtension() -> Bool {
        product == .systemExtension
    }

    /// Determines if the target is able to embed a watch application
    /// i.e. a product that can be bundled with a watchOS application
    func canEmbedWatchApplications() -> Bool {
        supports(.iOS) && product == .app
    }

    /// Determines if the target is able to embed an system extension
    /// i.e. a product that can be bundled with a macOS application
    func canEmbedSystemExtensions() -> Bool {
        supports(.macOS) && product == .app
    }

    /// Return the a set of PlatformFilters to control linking based on what platform is being compiled
    /// This allows a target to link against a dependency conditionally when it is being compiled for a compatible platform
    /// E.g. An app linking against CarPlay only when built for iOS.
    var dependencyPlatformFilters: PlatformFilters {
        Set(destinations.map(\.platformFilter))
    }

    /// Returns a new copy of the target with the given InfoPlist set.
    /// - Parameter infoPlist: InfoPlist to be set to the copied instance.
    func with(infoPlist: InfoPlist) -> Target {
        var copy = self
        copy.infoPlist = infoPlist
        return copy
    }

    /// Returns a new copy of the target with the given entitlements set.
    /// - Parameter entitlements: entitlements to be set to the copied instance.
    func with(entitlements: Entitlements) -> Target {
        var copy = self
        copy.entitlements = entitlements
        return copy
    }

    /// Returns a new copy of the target with the given scripts.
    /// - Parameter scripts: Actions to be set to the copied instance.
    func with(scripts: [TargetScript]) -> Target {
        var copy = self
        copy.scripts = scripts
        return copy
    }

    /// Returns a new copy of the target with the given additional settings
    /// - Parameter additionalSettings: settings to be added.
    func with(additionalSettings: SettingsDictionary, combineEqualSettings: Bool = false) -> Target {
        var copy = self
        if let oldSettings = copy.settings {
            copy.settings = Settings(
                base: oldSettings.base.merging(
                    additionalSettings,
                    uniquingKeysWith: { old, new in
                        return combineEqualSettings ? old.combine(with: new) : new
                    }
                ),
                configurations: oldSettings.configurations,
                defaultSettings: oldSettings.defaultSettings
            )
        } else {
            copy.settings = Settings(
                base: additionalSettings,
                configurations: [:]
            )
        }
        return copy
    }
}

extension Sequence<Target> {
    /// Filters and returns only the targets that are test bundles.
    var testBundles: [Target] {
        filter(\.product.testsBundle)
    }

    /// Filters and returns only the targets that are apps and app clips.
    var apps: [Target] {
        filter { $0.product == .app || $0.product == .appClip }
    }
}
