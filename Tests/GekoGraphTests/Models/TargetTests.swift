import Foundation
import ProjectDescription
import GekoCore
import GekoSupport

import GekoCoreTesting
import XCTest
@testable import GekoGraph
@testable import GekoGraphTesting
@testable import GekoSupportTesting

final class TargetErrorTests: GekoUnitTestCase {
    func test_description() {
        // Given
        let invalidGlobs: [InvalidGlob] = [.init(pattern: "**/*", nonExistentPath: .root)]

        // When
        let got = TargetError.invalidSourcesGlob(targetName: "Target", invalidGlobs: invalidGlobs).description

        // Then
        XCTAssertEqual(
            got,
            "The target Target has the following invalid source files globs:\n" + invalidGlobs.invalidGlobsDescription
        )
    }
}

final class TargetTests: GekoUnitTestCase {
    func test_validSourceExtensions() {
        XCTAssertEqual(
            Target.validSourceExtensions,
            [
                "m",
                "swift",
                "mm",
                "cpp",
                "cc",
                "c",
                "d",
                "s",
                "intentdefinition",
                "xcmappingmodel",
                "metal",
                "mlmodel",
                "docc",
                "playground",
                "rcproject",
                "mlpackage",
            ]
        )
    }

    func test_productNameWithExtension_when_staticLibrary() {
        let target = Target.test(name: "Test", product: .staticLibrary)
        XCTAssertEqual(target.productNameWithExtension, "libTest.a")
    }

    func test_productNameWithExtension_when_dynamicLibrary() {
        let target = Target.test(name: "Test", product: .dynamicLibrary)
        XCTAssertEqual(target.productNameWithExtension, "libTest.dylib")
    }

    func test_productNameWithExtension_when_nil() {
        let target = Target.test(name: "Test-Module", productName: nil)
        XCTAssertEqual(target.productName, "Test_Module")
    }

    func test_productNameWithExtension_when_app() {
        let target = Target.test(name: "Test", product: .app)
        XCTAssertEqual(target.productNameWithExtension, "Test.app")
    }

    func test_productNameWithExtension_when_appClip() {
        let target = Target.test(name: "Test", product: .appClip)
        XCTAssertEqual(target.productNameWithExtension, "Test.app")
    }

    func test_productNameWithExtension_when_macro() {
        let target = Target.test(name: "macro", product: .macro)
        XCTAssertEqual(target.productNameWithExtension, "macro")
    }

    func test_sequence_testBundles() {
        let app = Target.test(product: .app)
        let tests = Target.test(product: .unitTests)
        let targets = [app, tests]

        XCTAssertEqual(targets.testBundles, [tests])
    }

    func test_sequence_apps() {
        let app = Target.test(product: .app)
        let tests = Target.test(product: .unitTests)
        let targets = [app, tests]

        XCTAssertEqual(targets.apps, [app])
    }

    func test_sequence_appClips() {
        let appClip = Target.test(product: .appClip)
        let tests = Target.test(product: .unitTests)
        let targets = [appClip, tests]

        XCTAssertEqual(targets.apps, [appClip])
    }

    func test_supportsResources() {
        XCTAssertFalse(Target.test(product: .dynamicLibrary).supportsResources)
        XCTAssertFalse(Target.test(product: .staticLibrary).supportsResources)
        XCTAssertFalse(Target.test(product: .staticFramework).supportsResources)
        XCTAssertTrue(Target.test(product: .app).supportsResources)
        XCTAssertTrue(Target.test(product: .framework).supportsResources)
        XCTAssertTrue(Target.test(product: .unitTests).supportsResources)
        XCTAssertTrue(Target.test(product: .uiTests).supportsResources)
        XCTAssertTrue(Target.test(product: .bundle).supportsResources)
        XCTAssertTrue(Target.test(product: .appExtension).supportsResources)
        XCTAssertTrue(Target.test(product: .watch2App).supportsResources)
        XCTAssertTrue(Target.test(product: .watch2Extension).supportsResources)
        XCTAssertTrue(Target.test(product: .messagesExtension).supportsResources)
        XCTAssertTrue(Target.test(product: .stickerPackExtension).supportsResources)
        XCTAssertTrue(Target.test(product: .appClip).supportsResources)
    }

    func test_resources() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let folders = try createFolders([
            "resources/d.xcassets",
            "resources/d.scnassets",
            "resources/g.bundle",
        ])

        let files = try createFiles([
            "resources/a.png",
            "resources/b.jpg",
            "resources/b.jpeg",
            "resources/c.pdf",
            "resources/e.ttf",
            "resources/f.otf",
        ])

        let paths = folders + files

        // When
        let resources = paths.filter { Target.isResource(path: $0) }

        // Then
        let relativeResources = resources.map { $0.relative(to: temporaryPath).pathString }
        XCTAssertEqual(relativeResources, [
            "resources/d.xcassets",
            "resources/d.scnassets",
            "resources/g.bundle",
            "resources/a.png",
            "resources/b.jpg",
            "resources/b.jpeg",
            "resources/c.pdf",
            "resources/e.ttf",
            "resources/f.otf",
        ])
    }

    func test_dependencyPlatformFilters_when_iOS_targets_mac() {
        // Given
        let target = Target.test(destinations: [.macCatalyst])

        // When
        let got = target.dependencyPlatformFilters

        // Then
        XCTAssertEqual(got, [PlatformFilter.catalyst])
    }

    func test_dependencyPlatformFilters_when_iOS_and_doesnt_target_mac() {
        // Given
        let target = Target.test(destinations: .iOS)

        // When
        let got = target.dependencyPlatformFilters

        // Then
        XCTAssertEqual(got, [PlatformFilter.ios])
    }

    func test_dependencyPlatformFilters_when_iOS_and_catalyst() {
        // Given
        let target = Target.test(destinations: [.iPhone, .iPad, .macCatalyst])

        // When
        let got = target.dependencyPlatformFilters

        // Then
        XCTAssertEqual(got, [PlatformFilter.ios, PlatformFilter.catalyst])
    }

    func test_dependencyPlatformFilters_when_using_many_destinations() {
        // Given
        let target = Target.test(destinations: [.iPhone, .iPad, .macCatalyst, .mac, .appleVision])

        // When
        let got = target.dependencyPlatformFilters

        // Then
        XCTAssertEqual(got, [PlatformFilter.ios, PlatformFilter.catalyst, PlatformFilter.macos, PlatformFilter.visionos])
    }

    func test_supportsCatalyst_returns_true_when_the_destinations_include_macCatalyst() {
        // Given
        let target = Target.test(destinations: [.macCatalyst])

        // When
        let got = target.supportsCatalyst

        // Then
        XCTAssertTrue(got)
    }

    func test_supportsCatalyst_returns_false_when_the_destinations_include_macCatalyst() {
        // Given
        let target = Target.test(destinations: [.iPad])

        // When
        let got = target.supportsCatalyst

        // Then
        XCTAssertFalse(got)
    }

    func test_settings_with_additional_settings() throws {
        // Given
        let stubSettingsDict: SettingsDictionary = ["test": .string("test")]
        let target = Target.test(settings: nil)

        // When
        let got = target.with(additionalSettings: stubSettingsDict)
        let configurations = try XCTUnwrap(got.settings?.configurations)

        // Then
        XCTAssertEqual(got.settings?.base, stubSettingsDict)
        XCTAssertEmpty(configurations)
    }

    func test_settings_with_additional_settings_already_exist() {
        // Given
        let stubSettingsDict: SettingsDictionary = ["test": .string("wow")]
        let stubSettings = Settings.test(base: ["test": .string("test")], debug: .test(), release: .test())
        let target = Target.test(settings: stubSettings)

        // When
        let got = target.with(additionalSettings: stubSettingsDict)

        // Then
        XCTAssertEqual(got.settings?.base["test"], .string("wow"))
        XCTAssertEqual(got.settings?.configurations, stubSettings.configurations)
        XCTAssertEqual(got.settings?.defaultSettings, stubSettings.defaultSettings)
    }

    func test_settings_with_additional_settings_already_exist_combine_enabled() {
        // Given
        let stubSettingsDict: SettingsDictionary = ["test": .string("wow")]
        let stubSettings = Settings.test(base: ["test": .string("test")], debug: .test(), release: .test())
        let target = Target.test(settings: stubSettings)

        // When
        let got = target.with(additionalSettings: stubSettingsDict, combineEqualSettings: true)

        // Then
        XCTAssertEqual(got.settings?.base["test"], .array(["test", "wow"]))
        XCTAssertEqual(got.settings?.configurations, stubSettings.configurations)
        XCTAssertEqual(got.settings?.defaultSettings, stubSettings.defaultSettings)
    }
}
