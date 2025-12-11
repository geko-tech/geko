import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport
import XCTest

@testable import GekoLoader
@testable import GekoSupportTesting

final class SchemeManifestMapperTests: GekoUnitTestCase {
    func test_from_when_the_scheme_has_no_actions() throws {
        // Given
        let manifest = ProjectDescription.Scheme.manifestTest(
            name: "Scheme",
            shared: false
        )
        let projectPath = try AbsolutePath(validating: "/somepath/Project")
        let generatorPaths = GeneratorPaths(manifestDirectory: projectPath)

        // When
        var model = manifest
        try model.resolvePaths(generatorPaths: generatorPaths)

        // Then
        try assert(scheme: model, matches: manifest, path: projectPath, generatorPaths: generatorPaths)
    }

    func test_from_when_the_scheme_has_actions() throws {
        // Given
        let arguments = ProjectDescription.Arguments.manifestTest(
            environment: ["FOO": "BAR", "FIZ": "BUZZ"],
            launchArguments: [
                LaunchArgument(name: "--help", isEnabled: true),
                LaunchArgument(name: "subcommand", isEnabled: false),
            ]
        )

        let projectPath = try AbsolutePath(validating: "/somepath")
        let generatorPaths = GeneratorPaths(manifestDirectory: projectPath)

        let buildAction = ProjectDescription.BuildAction.manifestTest(targets: ["A", "B"])
        let runActions = ProjectDescription.RunAction.manifestTest(
            configuration: .release,
            executable: "A",
            arguments: arguments
        )
        let testAction = ProjectDescription.TestAction.manifestTest(
            targets: ["B"],
            arguments: arguments,
            configuration: .debug,
            coverage: true
        )
        let manifest = ProjectDescription.Scheme.manifestTest(
            name: "Scheme",
            shared: true,
            buildAction: buildAction,
            testAction: testAction,
            runAction: runActions
        )

        // When
        var model = manifest
        try model.resolvePaths(generatorPaths: generatorPaths)

        // Then
        try assert(scheme: model, matches: manifest, path: projectPath, generatorPaths: generatorPaths)
    }
}
