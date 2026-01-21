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

final class DependenciesModelLoaderTests: GekoUnitTestCase {
    private var manifestLoader: MockManifestLoader!

    private var subject: DependenciesModelLoader!

    override func setUp() {
        super.setUp()

        manifestLoader = MockManifestLoader()
        subject = DependenciesModelLoader(manifestLoader: manifestLoader)
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

        manifestLoader.loadDependenciesStub = { _ in
            Dependencies(
                cocoapods: nil
            )
        }

        // When
        let got = try subject.loadDependencies(at: temporaryPath, with: plugins)

        // Then
        let expected: Dependencies = .init(
            cocoapods: nil
        )
        XCTAssertEqual(manifestLoader.registerPluginsCount, 1)
        XCTAssertEqual(got, expected)
    }
}
