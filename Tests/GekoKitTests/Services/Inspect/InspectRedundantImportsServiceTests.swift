import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoCoreTesting
import GekoLoader
import GekoLoaderTesting
import GekoGraph
import GekoSupport
import GekoSupportTesting
import XCTest
@testable import GekoKit

final class InspectRedundantImportsServiceTests: GekoUnitTestCase {
    private var subject: InspectRedundantImportsService!
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
        subject = InspectRedundantImportsService(
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
    
    func test_run_throwsAnError_when_thereAreIssues_andSeverityError() async throws {
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
        
        let expectedError = LintingError()
        
        // When
        await XCTAssertThrowsSpecific(try await subject.run(
            path: path.pathString,
            severity: .error,
            inspectMode: .full,
            output: false
        ), expectedError)
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
        try await subject.run(
            path: path.pathString,
            severity: .warning,
            inspectMode: .full,
            output: false
        )
        
        // Then
        XCTAssertPrinterContains(" - App redundantly depends on: FrameworkB", at: .warning, ==)
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
        try await subject.run(
            path: path.pathString,
            severity: .warning,
            inspectMode: .full,
            output: true
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
        try await subject.run(
            path: path.pathString,
            severity: .warning,
            inspectMode: .diff,
            output: true
        )
        
        // Then
        XCTAssertPrinterContains(" - FrameworkA redundantly depends on: FrameworkC", at: .warning, ==)
        XCTAssertPrinterNotContains(" - FrameworkB redundantly depends on: FrameworkC", at: .warning, ==)
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
        try await subject.run(
            path: path.pathString,
            severity: .warning,
            inspectMode: .full,
            output: false
        )
        
        // Then
        XCTAssertPrinterContains("We did not find any redundant dependencies in your project.", at: .info, ==)
    }
}
