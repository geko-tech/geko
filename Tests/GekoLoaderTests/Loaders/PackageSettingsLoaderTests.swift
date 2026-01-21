import Foundation
import GekoCore
import GekoGraph
import GekoGraphTesting
import GekoSupport
import XCTest

import struct ProjectDescription.AbsolutePath

@testable import ProjectDescription
@testable import GekoLoader
@testable import GekoLoaderTesting
@testable import GekoSupportTesting

final class PackageSettingsLoaderTests: GekoUnitTestCase {
    private var manifestLoader: MockManifestLoader!
    private var subject: PackageSettingsLoader!

    override func setUp() {
        super.setUp()

        manifestLoader = MockManifestLoader()
        subject = PackageSettingsLoader(manifestLoader: manifestLoader)
    }

    override func tearDown() {
        subject = nil
        manifestLoader = nil

        super.tearDown()
    }

    func test_loadDependencies() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let plugins = Plugins.test()

        manifestLoader.loadPackageSettingsStub = { _ in
            PackageSettings()
        }

        // When
        let got = try subject.loadPackageSettings(at: temporaryPath, with: plugins)

        // Then
        let expected: PackageSettings = .init(
            productTypes: [:],
            baseSettings: .init(configurations: [
                .debug: .init(settings: [:], xcconfig: nil),
                .release: .init(settings: [:], xcconfig: nil),
            ])
        )
        XCTAssertEqual(manifestLoader.registerPluginsCount, 1)
        XCTAssertEqual(got, expected)
    }
}
