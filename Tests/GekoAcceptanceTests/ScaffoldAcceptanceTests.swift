#if os(macOS)

import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import GekoSupportTesting
import XcodeProj
import XCTest

final class ScaffoldAcceptanceTests: GekoAcceptanceTestCase {
    override func tearDown() {
        ScaffoldCommand.requiredTemplateOptions = []
        ScaffoldCommand.optionalTemplateOptions = []
        super.tearDown()
    }

// TODO: Uses swift package from github
//    func test_ios_app_with_templates_custom() async throws {
//        try setUpFixture(.iosAppWithTemplates)
//        try await run(FetchCommand.self)
//        try await ScaffoldCommand.preprocess([
//            "scaffold",
//            "custom",
//            "--name",
//            "TemplateProject",
//            "--path",
//            fixturePath.pathString,
//        ])
//        try await run(ScaffoldCommand.self, "custom", "--name", "TemplateProject")
//        let templateProjectDirectory = fixturePath.appending(component: "TemplateProject")
//        XCTAssertEqual(
//            try FileHandler.shared.readTextFile(templateProjectDirectory.appending(component: "custom.swift")),
//            "// this is test TemplateProject content"
//        )
//        XCTAssertEqual(
//            try FileHandler.shared.readTextFile(templateProjectDirectory.appending(component: "generated.swift")),
//            """
//            // Generated file with platform: ios and name: TemplateProject
//
//            """
//        )
//    }

// TODO: Uses swift package from github
//    func test_ios_app_with_templates_custom_using_filters() async throws {
//        try setUpFixture(.iosAppWithTemplates)
//        try await run(FetchCommand.self)
//        try await ScaffoldCommand.preprocess([
//            "scaffold",
//            "custom_using_filters",
//            "--name",
//            "TemplateProject",
//            "--path",
//            fixturePath.pathString,
//        ])
//        try await run(ScaffoldCommand.self, "custom_using_filters", "--name", "TemplateProject")
//        let templateProjectDirectory = fixturePath.appending(component: "TemplateProject")
//        XCTAssertEqual(
//            try FileHandler.shared.readTextFile(templateProjectDirectory.appending(component: "custom.swift")),
//            "// this is test TemplateProject content"
//        )
//    }

// TODO: Uses swift package from github
//    func test_ios_app_with_templates_custom_using_copy_folder() async throws {
//        try setUpFixture(.iosAppWithTemplates)
//        try await run(FetchCommand.self)
//        try await ScaffoldCommand.preprocess([
//            "scaffold",
//            "custom_using_copy_folder",
//            "--name",
//            "TemplateProject",
//            "--path",
//            fixturePath.pathString,
//        ])
//        try await run(ScaffoldCommand.self, "custom_using_copy_folder", "--name", "TemplateProject")
//        let templateProjectDirectory = fixturePath.appending(component: "TemplateProject")
//        XCTAssertEqual(
//            try FileHandler.shared.readTextFile(templateProjectDirectory.appending(component: "generated.swift")),
//            """
//            // Generated file with platform: ios and name: TemplateProject
//
//            """
//        )
//        XCTAssertEqual(
//            try FileHandler.shared.readTextFile(
//                templateProjectDirectory.appending(components: ["sourceFolder", "file1.txt"])
//            ),
//            """
//            Content of file 1
//
//            """
//        )
//        XCTAssertEqual(
//            try FileHandler.shared.readTextFile(
//                templateProjectDirectory.appending(components: ["sourceFolder", "subFolder", "file2.txt"])
//            ),
//            """
//            Content of file 2
//
//            """
//        )
//    }

    func test_app_with_plugins_local_plugin() async throws {
        throw XCTSkip("// TODO: Github")

        try setUpFixture(.appWithPlugins)
        try await run(FetchCommand.self)
        try await ScaffoldCommand.preprocess(["scaffold", "custom", "--name", "PluginTemplate", "--path", fixturePath.pathString])
        try await run(ScaffoldCommand.self, "custom", "--name", "PluginTemplate")
        let pluginTemplateDirectory = fixturePath.appending(component: "PluginTemplate")
        XCTAssertEqual(
            try FileHandler.shared.readTextFile(pluginTemplateDirectory.appending(component: "custom.swift")),
            "// this is test PluginTemplate content"
        )
        XCTAssertEqual(
            try FileHandler.shared.readTextFile(pluginTemplateDirectory.appending(component: "generated.swift")),
            """
            // Generated file with platform: ios and name: PluginTemplate

            """
        )
    }

    func test_app_with_plugins_remote_plugin() async throws {
        // TODO: Github publish example later
        throw XCTSkip("fixture appWithPlugins -> Config.swift git url")

        try setUpFixture(.appWithPlugins)
        try await run(FetchCommand.self)
        try await ScaffoldCommand.preprocess([
            "scaffold",
            "custom_two",
            "--name",
            "PluginTemplate",
            "--path",
            fixturePath.pathString,
        ])
        try await run(ScaffoldCommand.self, "custom_two", "--name", "PluginTemplate")
        let pluginTemplateDirectory = fixturePath.appending(component: "PluginTemplate")
        XCTAssertEqual(
            try FileHandler.shared.readTextFile(pluginTemplateDirectory.appending(component: "custom.swift")),
            "// this is test PluginTemplate content"
        )
        XCTAssertEqual(
            try FileHandler.shared.readTextFile(pluginTemplateDirectory.appending(component: "generated.swift")),
            """
            // Generated file with platform: ios and name: PluginTemplate

            """
        )
    }
}

#endif
