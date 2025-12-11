import TSCBasic
import XCTest
@testable import GekoDesktop

final class ConfigsProviderTests: XCTestCase {
    
    private var configsProvider: ConfigsProvider!
    private var project: UserProject!
    
    override func setUp() {
        super.setUp()
        configsProvider = ConfigsProvider()
        project = UserProject(name: "Test", path: AbsolutePath(stringLiteral: "/"))
    }
    
    override func tearDown() {
        configsProvider.removeConfig("TestConfig", for: project)
        configsProvider.removeConfig("TestConfig1", for: project)
        configsProvider.removeConfig("TestConfig2", for: project)
        configsProvider = nil
        super.tearDown()
    }


    func test_config_added_should_success() throws {
        let mockConfig = Configuration(
            name: "TestConfig",
            profile: "default",
            scheme: nil,
            deploymentTarget: "sim",
            options: [:],
            focusModules: ["test1", "test2"],
            userRegex: []
        )
        configsProvider.addConfig(mockConfig, for: project)
        let resultConfig = configsProvider.config(name: "TestConfig", for: project)
        XCTAssert(resultConfig != nil)
        XCTAssert(resultConfig!.name == mockConfig.name)
        XCTAssert(resultConfig!.profile == mockConfig.profile)
        XCTAssert(resultConfig!.deploymentTarget == mockConfig.deploymentTarget)
        XCTAssert(resultConfig!.options == mockConfig.options)
        XCTAssert(resultConfig!.focusModules == mockConfig.focusModules)
    }
    
    func test_config_updated_success() throws {
        let mockConfig = Configuration(
            name: "TestConfig",
            profile: "default",
            scheme: nil,
            deploymentTarget: "sim",
            options: [:],
            focusModules: ["test1", "test2"],
            userRegex: []
        )
        configsProvider.addConfig(mockConfig, for: project)
        let updatedConfig = Configuration(
            name: "TestConfig",
            profile: "newProfile",
            scheme: nil,
            deploymentTarget: "sim",
            options: [:],
            focusModules: ["test1", "test2", "test3"],
            userRegex: []
        )
        configsProvider.updateConfig(updatedConfig, for: project)
        let resultConfig = configsProvider.config(name: "TestConfig", for: project)
        XCTAssert(resultConfig != nil)
        XCTAssert(resultConfig!.name == updatedConfig.name)
        XCTAssert(resultConfig!.profile == updatedConfig.profile)
        XCTAssert(resultConfig!.deploymentTarget == updatedConfig.deploymentTarget)
        XCTAssert(resultConfig!.options == updatedConfig.options)
        XCTAssert(resultConfig!.focusModules == updatedConfig.focusModules)
    }
    
    func test_config_removed_success() throws {
        let mockConfig = Configuration(
            name: "TestConfig",
            profile: "default",
            scheme: nil,
            deploymentTarget: "sim",
            options: [:],
            focusModules: ["test1", "test2"],
            userRegex: []
        )
        configsProvider.addConfig(mockConfig, for: project)
        configsProvider.removeConfig("TestConfig", for: project)
        let resultConfig = configsProvider.config(name: "TestConfig", for: project)
        XCTAssert(resultConfig == nil)
    }
    
    func test_config_all_configs_success() throws {
        let firstConfig = Configuration(
            name: "TestConfig1",
            profile: "default",
            scheme: nil,
            deploymentTarget: "sim",
            options: [:],
            focusModules: ["test1", "test2"],
            userRegex: []
        )
        let secondConfig = Configuration(
            name: "TestConfig2",
            profile: "default",
            scheme: nil,
            deploymentTarget: "sim",
            options: [:],
            focusModules: ["test1", "test2"],
            userRegex: []
        )
        configsProvider.addConfig(firstConfig, for: project)
        configsProvider.addConfig(secondConfig, for: project)
        let allConfigs = configsProvider.allConfigs(for: project)
        XCTAssert(allConfigs.contains(firstConfig.name))
        XCTAssert(allConfigs.contains(secondConfig.name))
    }
    
    func test_config_selected_config_changed_success() throws {
        let firstConfig = Configuration(
            name: "TestConfig1",
            profile: "default",
            scheme: nil,
            deploymentTarget: "sim",
            options: [:],
            focusModules: ["test1", "test2"],
            userRegex: []
        )
        let secondConfig = Configuration(
            name: "TestConfig2",
            profile: "default",
            scheme: nil,
            deploymentTarget: "sim",
            options: [:],
            focusModules: ["test1", "test2"],
            userRegex: []
        )
        configsProvider.addConfig(firstConfig, for: project)
        configsProvider.addConfig(secondConfig, for: project)
        configsProvider.setSelectedConfig("TestConfig2", for: project)
        let resultConfig = configsProvider.selectedConfig(for: project)
        XCTAssert(resultConfig != nil)
        XCTAssert(resultConfig!.name == "TestConfig2")
    }
}
