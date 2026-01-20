import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoLoaderTesting
import GekoSupport
import XCTest

@testable import GekoGraph
@testable import GekoLoader
@testable import GekoSupportTesting

final class ProjectManifestMapperTests: GekoUnitTestCase {
    func test_from() throws {
        // Given
        var got = ProjectDescription.Project(
            name: "Name",
            organizationName: "Organization",
            options: .options(
                automaticSchemesOptions: .enabled(
                    targetSchemesGrouping: .byNameSuffix(build: ["build"], test: ["test"], run: ["run"]),
                    codeCoverageEnabled: true,
                    testingOptions: [.parallelizable]
                ),
                defaultKnownRegions: ["en-US", "Base"],
                developmentRegion: "us",
                disableBundleAccessors: true,
                disableShowEnvironmentVarsInScriptPhases: true,
                textSettings: .textSettings(usesTabs: true, indentWidth: 1, tabWidth: 2, wrapsLines: true),
                xcodeProjectName: "XcodeName"
            ),
            targets: [],
            schemes: [],
            fileHeaderTemplate: .string("123"),
            additionalFiles: [.glob(pattern: "/file.swift")]
        )
        fileHandler.stubExists = { _ in true }

        // When
        try got.resolvePaths(
            generatorPaths: .init(manifestDirectory: "/")
        )
        try got.resolveGlobs(checkFilesExist: true)

        // Then
        let expected = Project(
            path: "/",
            sourceRootPath: "/",
            xcodeProjPath: "/",
            name: "Name",
            organizationName: "Organization",
            options: .init(
                automaticSchemesOptions: .enabled(
                    targetSchemesGrouping: .byNameSuffix(build: ["build"], test: ["test"], run: ["run"]),
                    codeCoverageEnabled: true,
                    testingOptions: [.parallelizable]
                ),
                defaultKnownRegions: ["en-US", "Base"],
                developmentRegion: "us",
                disableBundleAccessors: true,
                disableShowEnvironmentVarsInScriptPhases: true,
                textSettings: .init(usesTabs: true, indentWidth: 1, tabWidth: 2, wrapsLines: true),
                xcodeProjectName: "XcodeName"
            ),
            settings: .default,
            filesGroup: .group(name: "Project"),
            targets: [],
            schemes: [],
            ideTemplateMacros: .init(fileHeader: "123"),
            additionalFiles: [.file(path: "/file.swift")],
            lastUpgradeCheck: nil,
            isExternal: false,
            projectType: .geko
        )
        XCTAssertEqual(got, expected)
    }
}
