import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport
import XCTest

@testable import GekoLoader
@testable import GekoSupportTesting

final class SettingsManifestMapperTests: GekoUnitTestCase {
    func test_from() throws {
        // Given
        let temporaryPath = try temporaryPath()
        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        let debug: ProjectDescription.Configuration = .debug(
            name: .debug,
            settings: ["Debug": .string("Debug")],
            xcconfig: "debug.xcconfig"
        )
        let release: ProjectDescription.Configuration = .release(
            name: .release,
            settings: ["Release": .string("Release")],
            xcconfig: "release.xcconfig"
        )
        let manifest: ProjectDescription.Settings = .settings(
            base: ["base": .string("base")],
            configurations: [
                debug,
                release,
            ]
        )

        // When
        var model = manifest
        try model.resolvePaths(generatorPaths: generatorPaths)

        // Then
        XCTAssertSettingsMatchesManifest(settings: model, matches: manifest, at: temporaryPath, generatorPaths: generatorPaths)
    }
}
