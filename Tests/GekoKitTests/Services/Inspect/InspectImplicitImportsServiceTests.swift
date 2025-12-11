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

final class InspectImplicitImportsServiceTests: GekoUnitTestCase {
    private var subject: InspectImplicitImportsService!
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
        subject = InspectImplicitImportsService(
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
        let framework = Target.test(name: "Framework", product: .framework)
        let frameworkGraphDep = GraphDependency.testTarget(name: "Framework", path: path)
        let project = Project.test(path: path, targets: [app, framework])
        let graph = Graph.test(
            path: path,
            projects: [path: project],
            targets: [path: ["App": app, "Framework": framework]],
            dependencies: [appGraphDep: [], frameworkGraphDep: []]
        )
        
        configLoader.loadConfigStub = { _ in config }
        generatorFactory.stubbedDefaultResult = generator
        generator.loadWithSideEffectsStub = { _ in (graph, .init(), [])}
        targetScanner.stubbedImportsResult = [
            app: Set(["Framework"]),
            framework: Set([])
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
        let framework = Target.test(name: "Framework", product: .framework)
        let frameworkGraphDep = GraphDependency.testTarget(name: "Framework", path: path)
        let project = Project.test(path: path, targets: [app, framework])
        let graph = Graph.test(
            path: path,
            projects: [path: project],
            targets: [path: ["App": app, "Framework": framework]],
            dependencies: [appGraphDep: [], frameworkGraphDep: []]
        )
        
        configLoader.loadConfigStub = { _ in config }
        generatorFactory.stubbedDefaultResult = generator
        generator.loadWithSideEffectsStub = { _ in (graph, .init(), [])}
        targetScanner.stubbedImportsResult = [
            app: Set(["Framework"]),
            framework: Set([])
        ]
        
        // When
        try await subject.run(
            path: path.pathString,
            severity: .warning,
            inspectMode: .full,
            output: false
        )
        
        // Then
        XCTAssertPrinterContains(" - App implicitly depends on: Framework", at: .warning, ==)
    }
    
    func test_run_saveToFile_when_thereAreIssues_severityWarning() async throws {
        // Given
        TestingLogHandler.reset()
        let path = try AbsolutePath(validating: "/project")
        let config = Config.test()
        let app = Target.test(name: "App", product: .app)
        let appGraphDep = GraphDependency.testTarget(name: "App", path: path)
        let framework = Target.test(name: "Framework", product: .framework)
        let frameworkGraphDep = GraphDependency.testTarget(name: "Framework", path: path)
        let project = Project.test(path: path, targets: [app, framework])
        let graph = Graph.test(
            path: path,
            projects: [path: project],
            targets: [path: ["App": app, "Framework": framework]],
            dependencies: [appGraphDep: [], frameworkGraphDep: []]
        )
        
        rootDirectoryLocator.locateStub = fileHandler.currentPath
        configLoader.loadConfigStub = { _ in config }
        generatorFactory.stubbedDefaultResult = generator
        generator.loadWithSideEffectsStub = { _ in (graph, .init(), [])}
        targetScanner.stubbedImportsResult = [
            app: Set(["Framework"]),
            framework: Set([])
        ]
        
        let expectedPath = fileHandler.currentPath.appending(components: [".geko", "Inspect", "implicity_imports.json"])
        
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
        XCTAssertEqual(["Framework"], result["App"])
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
            dependencies: [appGraphDep: [], frameworkAGraphDep: [], frameworkBGraphDep: [], frameworkCGraphDep: []]
        )
        
        system.stubs = ["git diff --name-only": (nil, frameworkASourceFile.paths[0].relative(to: graph.workspace.path).pathString, 0)]
        rootDirectoryLocator.locateStub = fileHandler.currentPath
        configLoader.loadConfigStub = { _ in config }
        generatorFactory.stubbedDefaultResult = generator
        generator.loadWithSideEffectsStub = { _ in (graph, .init(), [])}
        targetScanner.stubbedImportsResult = [
            app: Set([]),
            frameworkA: Set(["FrameworkC"]),
            frameworkB: Set(["FrameworkC"])
        ]
        
        // When
        try await subject.run(
            path: path.pathString,
            severity: .warning,
            inspectMode: .diff,
            output: true
        )
        
        // Then
        XCTAssertPrinterContains(" - FrameworkA implicitly depends on: FrameworkC", at: .warning, ==)
        XCTAssertPrinterNotContains(" - FrameworkB implicitly depends on: FrameworkC", at: .warning, ==)
    }
    
    func test_run_when_thereAreNoIssues_transitiveImported_andSeverityWarning() async throws {
        // Given
        TestingLogHandler.reset()
        let path = try AbsolutePath(validating: "/project")
        let config = Config.test()
        let app = Target.test(name: "App", product: .app)
        let appGraphDep = GraphDependency.testTarget(name: "App", path: path)
        let frameworkChild = Target.test(name: "FrameworkChild", product: .staticFramework)
        let frameworkChildGraphDep = GraphDependency.testTarget(name: "FrameworkChild", path: path)
        let frameworkParent = Target.test(name: "FrameworkParent", product: .staticFramework)
        let frameworkParentGraphDep = GraphDependency.testTarget(name: "FrameworkParent", path: path)
        let project = Project.test(path: path, targets: [app, frameworkChild, frameworkParent])
        let graph = Graph.test(
            path: path,
            projects: [path: project],
            targets: [path: ["App": app, "FrameworkChild": frameworkChild, "FrameworkParent": frameworkParent]],
            dependencies: [appGraphDep: [frameworkParentGraphDep], frameworkParentGraphDep: [frameworkChildGraphDep], frameworkChildGraphDep: []]
        )
        
        configLoader.loadConfigStub = { _ in config }
        generatorFactory.stubbedDefaultResult = generator
        generator.loadWithSideEffectsStub = { _ in (graph, .init(), [])}
        targetScanner.stubbedImportsResult = [
            app: Set(["FrameworkChild"]),
            frameworkChild: Set([]),
            frameworkParent: Set(["FrameworkChild"])
        ]
        
        // When
        try await subject.run(
            path: path.pathString,
            severity: .warning,
            inspectMode: .full,
            output: false
        )
        
        // Then
        XCTAssertPrinterContains("We did not find any implicit dependencies in your project.", at: .info, ==)
    }
    
    func test_run_printInfo_when_thereAreNoIssues_andSeverityWarning() async throws {
        // Given
        TestingLogHandler.reset()
        let path = try AbsolutePath(validating: "/project")
        let config = Config.test()
        let app = Target.test(name: "App", product: .app)
        let appGraphDep = GraphDependency.testTarget(name: "App", path: path)
        let framework = Target.test(name: "Framework", product: .framework)
        let frameworkGraphDep = GraphDependency.testTarget(name: "Framework", path: path)
        let project = Project.test(path: path, targets: [app, framework])
        let graph = Graph.test(
            path: path,
            projects: [path: project],
            targets: [path: ["App": app, "Framework": framework]],
            dependencies: [appGraphDep: [frameworkGraphDep], frameworkGraphDep: []]
        )
        
        configLoader.loadConfigStub = { _ in config }
        generatorFactory.stubbedDefaultResult = generator
        generator.loadWithSideEffectsStub = { _ in (graph, .init(), [])}
        targetScanner.stubbedImportsResult = [
            app: Set(["Framework"]),
            framework: Set([])
        ]
        
        // When
        try await subject.run(
            path: path.pathString,
            severity: .warning,
            inspectMode: .full,
            output: false
        )
        
        // Then
        XCTAssertPrinterContains("We did not find any implicit dependencies in your project.", at: .info, ==)
    }
}
