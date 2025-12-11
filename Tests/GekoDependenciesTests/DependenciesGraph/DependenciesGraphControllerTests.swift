import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoSupport
import XCTest

@testable import GekoDependencies
@testable import GekoDependenciesTesting
@testable import GekoGraphTesting
@testable import GekoSupportTesting

public final class DependenciesGraphControllerTests: GekoUnitTestCase {
    private var subject: DependenciesGraphController!

    override public func setUp() {
        super.setUp()
        subject = DependenciesGraphController()
    }

    override public func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_save() throws {
        // Given
        let root = try temporaryPath()
        let graph = GekoGraph.DependenciesGraph.test()

        // When
        try subject.save(graph, to: root)

        // Then
        let graphPath = root.appending(components: "Geko", "Dependencies", "graph.json")
        XCTAssertTrue(fileHandler.exists(graphPath))
    }

    func test_load() throws {
        // Given
        let root = try temporaryPath()

        let dependenciesPath = root.appending(components: "Geko", "Dependencies.swift")
        try fileHandler.touch(dependenciesPath)

        try fileHandler.write(GekoGraph.DependenciesGraph.testDependenciesFile, path: dependenciesPath, atomically: true)

        let graphPath = root.appending(components: "Geko", "Dependencies", "graph.json")
        try fileHandler.touch(graphPath)

        try fileHandler.write(GekoGraph.DependenciesGraph.testJson, path: graphPath, atomically: true)

        // When
        let got = try subject.load(at: root)

        // Then
        let expected = GekoGraph.DependenciesGraph(
            externalDependencies: ["SwiftLint": []],
            externalProjects: [:],
            externalFrameworkDependencies: [:],
            tree: ["SwiftLint": .init(version: "0.47.1", dependencies: [])]
        )

        XCTAssertEqual(got, expected)
    }

    func test_load_failed() throws {
        // Given
        let root = try temporaryPath()

        let dependenciesPath = root.appending(components: "Geko", "Dependencies.swift")
        try fileHandler.touch(dependenciesPath)

        try fileHandler.write(GekoGraph.DependenciesGraph.testDependenciesFile, path: dependenciesPath, atomically: true)

        let graphPath = root.appending(components: "Geko", "Dependencies", "graph.json")
        try fileHandler.touch(graphPath)

        try fileHandler.write(
            """
            {
              "externalDependencies": {},
              "externalProjects": [
                "ProjectPath",
                {
                  "invalid": "Project"
                }
              ]
            }
            """,
            path: graphPath,
            atomically: true
        )

        // When / Then
        XCTAssertThrowsSpecific(
            try subject.load(at: root),
            DependenciesGraphControllerError.failedToDecodeDependenciesGraph("""
            An error occured while parsing json file \(graphPath).
            Unable to find key 'name` at path 'root.externalProjects[1].name'.
            """)
        )
    }

    func test_load_without_fetching() throws {
        // Given
        let root = try temporaryPath()

        let dependenciesPath = root.appending(components: "Geko", "Dependencies.swift")
        try fileHandler.touch(dependenciesPath)

        try fileHandler.write(GekoGraph.DependenciesGraph.testDependenciesFile, path: dependenciesPath, atomically: true)

        // When / Then
        XCTAssertThrowsSpecific(
            try subject.load(at: root),
            DependenciesGraphControllerError.dependenciesWerentFetched
        )
    }

    func test_load_no_dependencies() throws {
        // Given
        let root = try temporaryPath()
        let dependenciesPath = root.appending(components: "Geko")
        try fileHandler.touch(dependenciesPath)

        // When / Then
        XCTAssertEqual(try subject.load(at: root), .none)
    }

    func test_clean() throws {
        // Given
        let root = try temporaryPath()
        let graphPath = root.appending(components: "Geko", "Dependencies", "graph.json")
        try fileHandler.touch(graphPath)

        // When
        try subject.clean(at: root)

        // Then
        XCTAssertFalse(fileHandler.exists(graphPath))
    }
}
