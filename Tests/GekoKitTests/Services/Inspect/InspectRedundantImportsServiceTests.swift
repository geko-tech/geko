import Foundation
import GekoCore
import GekoCoreTesting
import GekoLoader
import GekoLoaderTesting
import GekoGraph
import GekoSupport
import GekoSupportTesting
import ProjectDescription
import XCTest
@testable import GekoKit

final class InspectRedundantImportsServiceTests: GekoUnitTestCase {
    private var subject: InspectImportsService!
    private var targetScanner: MockTargetImportsScanner!
    private var generatorFactory: MockGeneratorFactory!
    private var configLoader: MockConfigLoader!
    private var generator: MockGenerator!
    private var ciChecker: MockCIChecker!
    private var rootDirectoryLocator: MockRootDirectoryLocator!

    override func setUp() {
        super.setUp()
        configLoader = MockConfigLoader()
        generatorFactory = MockGeneratorFactory()
        targetScanner = MockTargetImportsScanner()
        generator = MockGenerator()
        ciChecker = MockCIChecker()
        rootDirectoryLocator = MockRootDirectoryLocator()
        let graphImportsLinter = GraphImportsLinter(
            targetScanner: targetScanner,
            logDirectoryProvider: LogDirectoriesProvider(
                fileHandler: fileHandler,
                rootDirectoryLocator: rootDirectoryLocator
            ),
            fileHandler: fileHandler,
            environment: environment,
            system: system,
            ciChecker: ciChecker
        )
        subject = InspectImportsService(
            graphImportsLinter: graphImportsLinter,
            generatorFactory: generatorFactory,
            configLoader: configLoader,
            fileHandler: fileHandler
        )
    }

    override func tearDown() {
        subject = nil
        targetScanner = nil
        generatorFactory = nil
        configLoader = nil
        generator = nil
        super.tearDown()
    }

    func test_run_printWarning_when_thereAreIssues_andSeverityWarning() async throws {
        // Given
        TestingLogHandler.reset()
        let path = try AbsolutePath(validating: "/project")
        let config = Config.test()
        let app = Target.test(name: "App", product: .app)
        let appGraphDep = GraphDependency.testTarget(name: "App", path: path)
        let frameworkA = Target.test(name: "FrameworkA", product: .staticFramework)
        let frameworkAGraphDep = GraphDependency.testTarget(name: "FrameworkA", path: path)
        let frameworkB = Target.test(name: "FrameworkB", product: .staticFramework)
        let frameworkBGraphDep = GraphDependency.testTarget(name: "FrameworkB", path: path)
        let project = Project.test(path: path, targets: [app, frameworkA, frameworkB])
        let graph = Graph.test(
            path: path,
            projects: [path: project],
            targets: [path: ["App": app, "FrameworkA": frameworkA, "FrameworkB": frameworkB]],
            dependencies: [appGraphDep: [frameworkAGraphDep, frameworkBGraphDep], frameworkAGraphDep: [], frameworkBGraphDep: []]
        )

        configLoader.loadConfigStub = { _ in config }
        generatorFactory.stubbedDefaultResult = generator
        generator.loadWithSideEffectsStub = { _ in (graph, .init(), [])}
        targetScanner.stubbedImportsResult = [
            app: Set(["FrameworkA"]),
            frameworkA: Set([]),
            frameworkB: Set([])
        ]

        // When
        let issues = try await subject.run(
            path: path,
            severity: .warning,
            inspectType: .redundant,
            inspectMode: .full,
            output: nil
        )

        // Then
        XCTAssertEqual(issues, [
            LintingIssue(reason: " - App redundantly depends on: FrameworkB", severity: .warning)
        ])
    }

    func test_run_saveToFile_when_thereAreIssues_severityWarning() async throws {
        // Given
        TestingLogHandler.reset()
        let path = try AbsolutePath(validating: "/project")
        let config = Config.test()
        let app = Target.test(name: "App", product: .app)
        let appGraphDep = GraphDependency.testTarget(name: "App", path: path)
        let frameworkA = Target.test(name: "FrameworkA", product: .staticFramework)
        let frameworkAGraphDep = GraphDependency.testTarget(name: "FrameworkA", path: path)
        let frameworkB = Target.test(name: "FrameworkB", product: .staticFramework)
        let frameworkBGraphDep = GraphDependency.testTarget(name: "FrameworkB", path: path)
        let project = Project.test(path: path, targets: [app, frameworkA, frameworkB])
        let graph = Graph.test(
            path: path,
            projects: [path: project],
            targets: [path: ["App": app, "FrameworkA": frameworkA, "FrameworkB": frameworkB]],
            dependencies: [appGraphDep: [frameworkAGraphDep, frameworkBGraphDep], frameworkAGraphDep: [], frameworkBGraphDep: []]
        )

        rootDirectoryLocator.locateStub = fileHandler.currentPath
        configLoader.loadConfigStub = { _ in config }
        generatorFactory.stubbedDefaultResult = generator
        generator.loadWithSideEffectsStub = { _ in (graph, .init(), [])}
        targetScanner.stubbedImportsResult = [
            app: Set(["FrameworkA"]),
            frameworkA: Set([]),
            frameworkB: Set([])
        ]

        let expectedPath = fileHandler.currentPath.appending(components: [".geko", "Inspect", "redundant_imports.json"])

        // When
        _ = try await subject.run(
            path: path,
            severity: .warning,
            inspectType: .redundant,
            inspectMode: .full,
            output: expectedPath
        )

        // Then
        XCTAssertTrue(fileHandler.exists(expectedPath))
        let data = try fileHandler.readFile(expectedPath)
        let result = try JSONDecoder().decode([String: Set<String>].self, from: data)
        XCTAssertEqual(["FrameworkB"], result["App"])
    }

    func test_run_printInfo_when_thereAreIssuesOutOfTheDiff_severityWarning_diffMode() async throws {
        // Given
        TestingLogHandler.reset()
        let path = try AbsolutePath(validating: "/project")
        let config = Config.test()
        let app = Target.test(name: "App", product: .app)
        let appGraphDep = GraphDependency.testTarget(name: "App", path: path)
        let frameworkASourceFile = SourceFiles(paths: [path.appending(component: "FrameworkAFile.swift")])
        let frameworkA = Target.test(name: "FrameworkA", product: .staticFramework, sources: [frameworkASourceFile])
        let frameworkAGraphDep = GraphDependency.testTarget(name: "FrameworkA", path: path)
        let frameworkB = Target.test(name: "FrameworkB", product: .staticFramework)
        let frameworkBGraphDep = GraphDependency.testTarget(name: "FrameworkB", path: path)
        let frameworkBSourceFile = SourceFiles(paths: [path.appending(component: "FrameworkBFile.swift")])
        let frameworkC = Target.test(name: "FrameworkC", product: .staticFramework, sources: [frameworkBSourceFile])
        let frameworkCGraphDep = GraphDependency.testTarget(name: "FrameworkC", path: path)
        let project = Project.test(path: path, targets: [app, frameworkA, frameworkB, frameworkC])
        let graph = Graph.test(
            path: path,
            projects: [path: project],
            targets: [path: ["App": app, "FrameworkA": frameworkA, "FrameworkB": frameworkB, "FrameworkC": frameworkC]],
            dependencies: [appGraphDep: [], frameworkAGraphDep: [frameworkCGraphDep], frameworkBGraphDep: [frameworkCGraphDep], frameworkCGraphDep: []]
        )

        system.stubs = ["git diff --name-only": (nil, frameworkASourceFile.paths[0].relative(to: graph.workspace.path).pathString, 0)]
        rootDirectoryLocator.locateStub = fileHandler.currentPath
        configLoader.loadConfigStub = { _ in config }
        generatorFactory.stubbedDefaultResult = generator
        generator.loadWithSideEffectsStub = { _ in (graph, .init(), [])}
        targetScanner.stubbedImportsResult = [
            app: Set([]),
            frameworkA: Set([]),
            frameworkB: Set([])
        ]

        // When
        let issues = try await subject.run(
            path: path,
            severity: .warning,
            inspectType: .redundant,
            inspectMode: .diff,
            output: nil
        )

        // Then
        XCTAssertEqual(issues, [
            LintingIssue(reason: " - FrameworkA redundantly depends on: FrameworkC", severity: .warning)
        ])
    }

    func test_run_printInfo_when_thereAreNoIssues_andSeverityWarning() async throws {
        // Given
        TestingLogHandler.reset()
        let path = try AbsolutePath(validating: "/project")
        let config = Config.test()
        let app = Target.test(name: "App", product: .app)
        let appGraphDep = GraphDependency.testTarget(name: "App", path: path)
        let frameworkA = Target.test(name: "FrameworkA", product: .staticFramework)
        let frameworkAGraphDep = GraphDependency.testTarget(name: "FrameworkA", path: path)
        let frameworkB = Target.test(name: "FrameworkB", product: .staticFramework)
        let frameworkBGraphDep = GraphDependency.testTarget(name: "FrameworkB", path: path)
        let project = Project.test(path: path, targets: [app, frameworkA, frameworkB])
        let graph = Graph.test(
            path: path,
            projects: [path: project],
            targets: [path: ["App": app, "FrameworkA": frameworkA, "FrameworkB": frameworkB]],
            dependencies: [appGraphDep: [frameworkAGraphDep, frameworkBGraphDep], frameworkAGraphDep: [], frameworkBGraphDep: []]
        )

        configLoader.loadConfigStub = { _ in config }
        generatorFactory.stubbedDefaultResult = generator
        generator.loadWithSideEffectsStub = { _ in (graph, .init(), [])}
        targetScanner.stubbedImportsResult = [
            app: Set(["FrameworkA", "FrameworkB"]),
            frameworkA: Set([]),
            frameworkB: Set([])
        ]

        // When
        let issues = try await subject.run(
            path: path,
            severity: .warning,
            inspectType: .redundant,
            inspectMode: .full,
            output: nil
        )

        // Then
        XCTAssertEmpty(issues)
    }
}
