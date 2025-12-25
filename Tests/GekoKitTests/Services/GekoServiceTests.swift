import struct ProjectDescription.AbsolutePath
import GekoLoaderTesting
import GekoPlugin
import GekoPluginTesting
import GekoSupport
import GekoSupportTesting
import XCTest

@testable import GekoKit

final class GekoServiceTests: GekoUnitTestCase {
    private var subject: GekoService!
    private var pluginsFacade: MockPluginsFacade!
    private var configLoader: MockConfigLoader!
    private var pluginExecutor: MockPluginExecutor!

    override func setUp() {
        super.setUp()
        pluginsFacade = MockPluginsFacade()
        configLoader = MockConfigLoader()
        pluginExecutor = MockPluginExecutor()
        subject = GekoService(
            pluginsFacade: pluginsFacade,
            configLoader: configLoader,
            pluginExecutor: pluginExecutor
        )
    }

    override func tearDown() {
        pluginsFacade = nil
        configLoader = nil
        subject = nil
        super.tearDown()
    }

    func test_run_when_command_not_found() throws {
        XCTAssertThrowsSpecific(
            try subject.run(arguments: ["my-command"], gekoBinaryPath: ""),
            GekoPluginExecutablePathBuilderError.pluginNotFound(pluginName: "my-command")
        )
    }

    func test_run_when_plugin_executable() throws {
        // Given
        let path = try temporaryPath()
        let projectPath = path.appending(component: "Project")
        let pluginReleasePath = path.appending(component: "Plugins")
        try fileHandler.touch(pluginReleasePath.appending(component: "executable-a"))
        try fileHandler.touch(pluginReleasePath.appending(component: "executable-b"))
        system.succeedCommand([
            pluginReleasePath.appending(component: "executable-b").pathString,
            "--path",
            projectPath.pathString,
        ])
        var loadConfigPath: AbsolutePath?
        configLoader.loadConfigStub = { configPath in
            loadConfigPath = configPath
            return .default
        }
        pluginsFacade.executablePluginsStub = { _ in
            [
                ExecutablePluginGeko(name: "plugin",
                                     executablePaths: [
                                        ExecutablePath(name: "executable-a", path: pluginReleasePath),
                                        ExecutablePath(name: "executable-b", path: pluginReleasePath)
                                     ])
            ]
        }
        system.succeedCommand(["plugin executable-b"])

        // When/Then
        XCTAssertNoThrow(
            try subject.run(arguments: ["plugin", "executable-b", "--path", projectPath.pathString], gekoBinaryPath: "")
        )
        XCTAssertEqual(loadConfigPath, projectPath)
    }
}
