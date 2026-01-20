#if os(macOS)

import GekoGraph
import GekoGraphTesting
import GekoPluginTesting
import ProjectDescription
import XCTest

@testable import GekoCore
@testable import GekoKit
@testable import GekoLoaderTesting
@testable import GekoScaffoldTesting
@testable import GekoSupportTesting

final class ListServiceTests: GekoUnitTestCase {
    var subject: ListService!
    var pluginsFacade: MockPluginsFacade!
    var templateLoader: MockTemplateLoader!
    var templatesDirectoryLocator: MockTemplatesDirectoryLocator!

    override func setUp() {
        super.setUp()
        pluginsFacade = MockPluginsFacade()
        templateLoader = MockTemplateLoader()
        templatesDirectoryLocator = MockTemplatesDirectoryLocator()
        subject = ListService(
            pluginsFacade: pluginsFacade,
            templatesDirectoryLocator: templatesDirectoryLocator,
            templateLoader: templateLoader
        )
    }

    override func tearDown() {
        subject = nil
        pluginsFacade = nil
        templateLoader = nil
        templatesDirectoryLocator = nil
        super.tearDown()
    }

    func test_lists_available_templates_table_format() async throws {
        // Given
        let expectedTemplates = ["template", "customTemplate"]
        let expectedOutput = """
        Name            Description
        ──────────────  ───────────
        template        description
        customTemplate  description
        """

        templatesDirectoryLocator.templateDirectoriesStub = { _ in
            try expectedTemplates.map(self.temporaryPath().appending)
        }

        templateLoader.loadTemplateStub = { _ in
            Template(description: "description", items: [])
        }

        // When
        try await subject.run(path: nil, outputFormat: .table)

        // Then
        XCTAssertPrinterContains(expectedOutput, at: .info, ==)
    }

    func test_lists_available_templates_json_format() async throws {
        // Given
        let expectedTemplates = ["template", "customTemplate"]
        let expectedOutput = """
        [
          {
            "description": "description",
            "name": "template"
          },
          {
            "description": "description",
            "name": "customTemplate"
          }
        ]
        """

        templatesDirectoryLocator.templateDirectoriesStub = { _ in
            try expectedTemplates.map(self.temporaryPath().appending)
        }

        templateLoader.loadTemplateStub = { _ in
            Template(description: "description", items: [])
        }

        // When
        try await subject.run(path: nil, outputFormat: .json)

        // Then
        XCTAssertPrinterContains(expectedOutput, at: .info, ==)
    }

    func test_lists_available_templates_with_plugins() async throws {
        // Given
        let expectedTemplates = ["template", "customTemplate", "pluginTemplate"]
        let expectedOutput = """
        Name            Description
        ──────────────  ───────────
        template        description
        customTemplate  description
        pluginTemplate  description
        """

        let pluginTemplatePath = try temporaryPath().appending(component: "PluginTemplate")
        pluginsFacade.loadPluginsStub = { _ in
            Plugins.test(templatePaths: [pluginTemplatePath])
        }

        templatesDirectoryLocator.templateDirectoriesStub = { _ in
            try expectedTemplates.map(self.temporaryPath().appending)
        }

        templateLoader.loadTemplateStub = { _ in
            Template(description: "description", items: [])
        }

        // When
        try await subject.run(path: nil, outputFormat: .table)

        // Then
        XCTAssertPrinterContains(expectedOutput, at: .info, ==)
    }
}

#endif
