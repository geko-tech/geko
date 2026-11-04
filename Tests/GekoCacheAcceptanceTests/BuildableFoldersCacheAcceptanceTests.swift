#if os(macOS)
import Foundation
import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import GekoSupportTesting
import XcodeProj
import XCTest

final class BuildableFoldersCacheAcceptanceTest: GekoAcceptanceTestCase {
    func test_ios_app_with_buildable_folders_cache() async throws {
        // Given
        TestingLogHandler.reset()
        try setUpFixture(.custom("ios_app_with_buildable_folders"))

        // When
        try await run(FetchCommand.self)
        try await run(GenerateCommand.self, arguments: ["--cache", "--ignore-remote-cache"])

        // Then
        XCTAssertStandardOutput(pattern: "Targets to be cached now count: 1")
        XCTAssertStandardOutput(pattern: "Building cacheable targets for platform iOS")
        XCTAssertStandardOutput(pattern: "Storing 1 cacheable targets")
        XCTAssertStandardOutput(pattern: "Stored 1 cacheable targets. Targets: Framework")
        XCTAssertStandardOutput(pattern: "All cacheable targets have been cached successfully as frameworks with simulator destination.")

        // The Framework target is replaced by the cached framework and removed from the generated project.
        // The App target is not cacheable, so it stays in the project.
        let appProject = try XcodeProj(pathString: xcodeprojPath.pathString)
        let projectTargets = appProject.pbxproj.projects.first?.targets.map { $0.name }.sorted()
        XCTAssertEqual(projectTargets, ["App"])

        // Rebuild with the same cache
        // When
        TestingLogHandler.reset()
        try await run(GenerateCommand.self, arguments: ["--cache", "--ignore-remote-cache"])

        // Then
        XCTAssertStandardOutput(
            pattern:
            """
            All cacheable targets are already cached
            """
        )
    }

    func test_ios_app_with_buildable_folders_cache_invalidatedOnlyByNonExceptionFiles() async throws {
        // Given
        TestingLogHandler.reset()
        try setUpFixture(.custom("ios_app_with_buildable_folders"))
        try await run(FetchCommand.self)
        try await run(GenerateCommand.self, arguments: ["--cache", "--ignore-remote-cache"])
        XCTAssertStandardOutput(pattern: "All cacheable targets have been cached successfully as frameworks with simulator destination.")

        // When a non-exception file inside a buildable folder changes, the cache is invalidated
        TestingLogHandler.reset()
        try addEmptyLine(to: "Framework/Sources/Framework.swift")
        try await run(GenerateCommand.self, arguments: ["--cache", "--ignore-remote-cache"])

        // Then
        XCTAssertStandardOutput(pattern: "Storing 1 cacheable targets")

        // When only an exception file changes, the cache is NOT invalidated
        TestingLogHandler.reset()
        try addEmptyLine(to: "Framework/Sources/Generated/GeneratedFile.swift")
        try await run(GenerateCommand.self, arguments: ["--cache", "--ignore-remote-cache"])

        // Then
        XCTAssertStandardOutput(
            pattern:
            """
            All cacheable targets are already cached
            """
        )

        // When a file-level exception changes, the cache is NOT invalidated either
        TestingLogHandler.reset()
        try addEmptyLine(to: "Framework/Sources/Excluded.swift")
        try await run(GenerateCommand.self, arguments: ["--cache", "--ignore-remote-cache"])

        // Then
        XCTAssertStandardOutput(
            pattern:
            """
            All cacheable targets are already cached
            """
        )
    }
}
#endif