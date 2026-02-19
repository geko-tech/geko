import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import XCTest
import GekoPluginTesting
import ProjectDescription

@testable import GekoPlugin
@testable import GekoSupportTesting

final class WorkspaceMapperPluginLoaderTests: GekoUnitTestCase {

    var path: AbsolutePath!
    var pluginsFacadeMock: MockPluginsFacade!
    var gekoPluginLoaderMock: MockGekoPluginLoader!

    override func setUp() {
        super.setUp()
        self.path = try! temporaryPath()
        self.pluginsFacadeMock = MockPluginsFacade()
        self.gekoPluginLoaderMock = MockGekoPluginLoader()

        gekoPluginLoaderMock.loadGekoPluginStubs = [{ _, _ in GekoPlugin()}]
    }

    override func tearDown() {
        self.path = nil
        self.pluginsFacadeMock = nil
        self.gekoPluginLoaderMock = nil
        super.tearDown()
    }

    func test_plugin_not_found() async throws {
        // given
        let gekoProjectDescriptionVersion = "release/0.10.2"
        let pluginProjectDescriptionVersion = "release/0.10.3"

        let workspaceMapperName = "TestWorkspaceMapper"
        let subject = setupSubject(
            workspaceMapperName: workspaceMapperName,
            gekoProjectDescriptionVersion: gekoProjectDescriptionVersion,
            pluginProjectDescriptionVersion: pluginProjectDescriptionVersion
        )

        // when & then
        await XCTAssertThrowsSpecific(
            try await subject.loadPlugins(using: .test(), workspaceMappers: [WorkspaceMapper(name: "NonExistentWorkspaceMapperPlugin", params: [:])], generationOptions: .test()),
            WorkspaceMapperPluginLoaderError.pluginNotFound(pluginName: "NonExistentWorkspaceMapperPlugin")
        )
    }

    func test_plugin_pd_version_greater_than_geko_pd_version() async throws {
        let gekoProjectDescriptionVersion = "release/0.10.2"
        let pluginProjectDescriptionVersion = "release/0.10.3"

        let workspaceMapperName = "TestWorkspaceMapper"
        let subject = setupSubject(
            workspaceMapperName: workspaceMapperName,
            gekoProjectDescriptionVersion: gekoProjectDescriptionVersion,
            pluginProjectDescriptionVersion: pluginProjectDescriptionVersion
        )

        // when & then
        await XCTAssertThrowsSpecific(
            try await subject.loadPlugins(using: .test(), workspaceMappers: [WorkspaceMapper(name: workspaceMapperName, params: [:])], generationOptions: .test()),
            WorkspaceMapperPluginLoaderError.pluginProjectDescriptionVersionGreaterThanGekoSupported(
                pluginName: workspaceMapperName,
                pluginProjectDescriptionVersion: pluginProjectDescriptionVersion,
                projectDescriptionVersion: gekoProjectDescriptionVersion
            )
        )
    }

    func test_different_major_versions() async throws {
        let gekoProjectDescriptionVersion = "release/1.0.0"
        let pluginProjectDescriptionVersion = "release/2.0.0"

        let workspaceMapperName = "TestWorkspaceMapper"
        let subject = setupSubject(
            workspaceMapperName: workspaceMapperName,
            gekoProjectDescriptionVersion: gekoProjectDescriptionVersion,
            pluginProjectDescriptionVersion: pluginProjectDescriptionVersion
        )

        // when & then
        await XCTAssertThrowsSpecific(
            try await subject.loadPlugins(using: .test(), workspaceMappers: [WorkspaceMapper(name: workspaceMapperName, params: [:])], generationOptions: .test()),
            WorkspaceMapperPluginLoaderError.pluginProjectDescriptionVersionMismatch(
                pluginName: workspaceMapperName,
                pluginProjectDescriptionVersion: pluginProjectDescriptionVersion,
                projectDescriptionVersion: gekoProjectDescriptionVersion,
                projectDescriptionVersionParsed: Version(string: gekoProjectDescriptionVersion.dropPrefix("release/"))!
            )
        )
    }

    func test_different_minor_versions() async throws {
        let gekoProjectDescriptionVersion = "release/1.1.0"
        let pluginProjectDescriptionVersion = "release/1.2.0"

        let workspaceMapperName = "TestWorkspaceMapper"
        let subject = setupSubject(
            workspaceMapperName: workspaceMapperName,
            gekoProjectDescriptionVersion: gekoProjectDescriptionVersion,
            pluginProjectDescriptionVersion: pluginProjectDescriptionVersion
        )

        // when & then
        await XCTAssertThrowsSpecific(
            try await subject.loadPlugins(using: .test(), workspaceMappers: [WorkspaceMapper(name: workspaceMapperName, params: [:])], generationOptions: .test()),
            WorkspaceMapperPluginLoaderError.pluginProjectDescriptionVersionMismatch(
                pluginName: workspaceMapperName,
                pluginProjectDescriptionVersion: pluginProjectDescriptionVersion,
                projectDescriptionVersion: gekoProjectDescriptionVersion,
                projectDescriptionVersionParsed: Version(string: gekoProjectDescriptionVersion.dropPrefix("release/"))!
            )
        )
    }

    func test_exact_versions() async throws {
        let gekoProjectDescriptionVersion = "release/1.1.0"
        let pluginProjectDescriptionVersion = "release/1.1.0"

        let workspaceMapperName = "TestWorkspaceMapper"
        let subject = setupSubject(
            workspaceMapperName: workspaceMapperName,
            gekoProjectDescriptionVersion: gekoProjectDescriptionVersion,
            pluginProjectDescriptionVersion: pluginProjectDescriptionVersion
        )

        // when & then
        await XCTAssertNoThrows(
            try await subject.loadPlugins(using: .test(), workspaceMappers: [WorkspaceMapper(name: workspaceMapperName, params: [:])], generationOptions: .test())
        )
    }

    func test_geko_pd_version_greater_than_plugin_pd_version() async throws {
        let gekoProjectDescriptionVersion = "release/1.1.3"
        let pluginProjectDescriptionVersion = "release/1.1.0"

        let workspaceMapperName = "TestWorkspaceMapper"
        let subject = setupSubject(
            workspaceMapperName: workspaceMapperName,
            gekoProjectDescriptionVersion: gekoProjectDescriptionVersion,
            pluginProjectDescriptionVersion: pluginProjectDescriptionVersion
        )

        // when & then
        await XCTAssertNoThrows(
            try await subject.loadPlugins(using: .test(), workspaceMappers: [WorkspaceMapper(name: workspaceMapperName, params: [:])], generationOptions: .test())
        )
    }

    func test_plugin_pd_version_parsing_error() async throws {
        let gekoProjectDescriptionVersion = "release/1.2.4"
        let pluginProjectDescriptionVersion = "not_release_branch/1.2.3"

        let workspaceMapperName = "TestWorkspaceMapper"
        let subject = setupSubject(
            workspaceMapperName: workspaceMapperName,
            gekoProjectDescriptionVersion: gekoProjectDescriptionVersion,
            pluginProjectDescriptionVersion: pluginProjectDescriptionVersion
        )

        // when & then
        await XCTAssertThrowsSpecific(
            try await subject.loadPlugins(using: .test(), workspaceMappers: [WorkspaceMapper(name: workspaceMapperName, params: [:])], generationOptions: .test()),
            WorkspaceMapperPluginLoaderError.pluginProjectDescriptionError(
                pluginName: workspaceMapperName,
                pluginProjectDescriptionVersion: pluginProjectDescriptionVersion
            )
        )
    }

    func test_plugin_pd_version_parsing_error2() async throws {
        let gekoProjectDescriptionVersion = "release/1.2.4"
        let pluginProjectDescriptionVersion = "not_release_branch/task-123"

        let workspaceMapperName = "TestWorkspaceMapper"
        let subject = setupSubject(
            workspaceMapperName: workspaceMapperName,
            gekoProjectDescriptionVersion: gekoProjectDescriptionVersion,
            pluginProjectDescriptionVersion: pluginProjectDescriptionVersion
        )

        // when & then
        await XCTAssertThrowsSpecific(
            try await subject.loadPlugins(using: .test(), workspaceMappers: [WorkspaceMapper(name: workspaceMapperName, params: [:])], generationOptions: .test()),
            WorkspaceMapperPluginLoaderError.pluginProjectDescriptionError(
                pluginName: workspaceMapperName,
                pluginProjectDescriptionVersion: pluginProjectDescriptionVersion
            )
        )
    }

    // MARK: - Private

    private func setupSubject(
        workspaceMapperName: String,
        gekoProjectDescriptionVersion: String,
        pluginProjectDescriptionVersion: String
    ) -> WorkspaceMapperPluginLoader {
        pluginsFacadeMock.workspaceMapperPluginsStub = { [path] _ in
            [
                WorkspaceMapperPluginPath(
                    name: workspaceMapperName,
                    path: path!,
                    info: PluginInfo(projectDescriptionVersion: pluginProjectDescriptionVersion)
                )
            ]
        }

        let projectDescriptionVersionProvider = ProjectDescriptionVersionProvider(projectDescriptionVersion: gekoProjectDescriptionVersion)

        return WorkspaceMapperPluginLoader(
            projectDescriptionVersionProvider: projectDescriptionVersionProvider,
            isStage: false,
            pluginsFacade: pluginsFacadeMock,
            gekoPluginLoader: gekoPluginLoaderMock
        )
    }
}

