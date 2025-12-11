import Foundation
import XCTest

@testable import GekoLoader
@testable import GekoSupportTesting

final class ManifestTests: GekoUnitTestCase {
    func test_fileName() throws {
        let temporaryPath = try temporaryPath().appending(component: "folder")

        XCTAssertEqual(Manifest.project.fileName(temporaryPath), "Project.swift")
        XCTAssertEqual(Manifest.workspace.fileName(temporaryPath), "Workspace.swift")
        XCTAssertEqual(Manifest.config.fileName(temporaryPath), "Config.swift")
        XCTAssertEqual(Manifest.dependencies.fileName(temporaryPath), "Dependencies.swift")
        XCTAssertEqual(Manifest.plugin.fileName(temporaryPath), "Plugin.swift")
        XCTAssertEqual(Manifest.template.fileName(temporaryPath), "folder.swift")
    }
}
