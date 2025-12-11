import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import GekoSupportTesting
import XCTest
import XcodeProj

final class PluginAcceptanceTestAppWithPlugins: GekoAcceptanceTestCase {
    func test_app_with_plugins() async throws {
        // TODO: Github publish example later
        throw XCTSkip("fixture appWithPlugins -> Config.swift git url")

        try setUpFixture(.appWithPlugins)
        try await run(FetchCommand.self)
#if os(macOS)
        try await run(GenerateCommand.self)
        try await run(BuildCommand.self)
#endif
    }
}

final class PluginAcceptanceWorkspaceMapper: GekoAcceptanceTestCase {
    func test_app_with_plugins() async throws {
        // given
        try setUpFixtureWorkspaceMapperPlugin(.gekoWorkspaceMapperPlugin)
        try await run(PluginArchiveCommannd.self, "--no-zip", "--configuration", "debug")
        try setUpFixture(.gekoWorkspaceMapperProject)

        // when
        try await run(FetchCommand.self)
#if os(macOS)
        try await run(GenerateCommand.self)

        // then
        XCTAssertStandardOutput(pattern: "Generating workspace GekoWorkspaceMapperTest-WorkspaceNameFromPlugin.xcworkspace")
#else
        do {
            try await run(GenerateCommand.self)
        } catch {
            XCTAssertEqual(error.localizedDescription, "The operation could not be completed. (GekoSupport.XcodeController.XcodeVersionError error 0.)")
        }
#endif
    }
}
