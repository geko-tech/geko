import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport
import XCTest

import struct ProjectDescription.AbsolutePath

@testable import GekoLoader
@testable import GekoSupportTesting

final class DependenciesManifestMapperTests: GekoUnitTestCase {
    func test_from() throws {
        // Given
        let temporaryPath = try temporaryPath()

        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)
        var got: ProjectDescription.Dependencies = Dependencies()

        // When
        try got.resolvePaths(generatorPaths: generatorPaths)

        // Then
        let expected: Dependencies = .init(
            cocoapods: nil
        )
        XCTAssertEqual(got, expected)
    }

    func testCocoapodsDependenciesMapperWithoutLocalPodspecs() throws {
        // arrange
        let temporaryPath = try temporaryPath()

        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)

        var result: ProjectDescription.CocoapodsDependencies = .init(
            repos: ["a"],
            dependencies: [.cdn(name: "a", requirement: .atLeast("0"), source: "source")]
        )

        // act
        try result.resolvePaths(generatorPaths: generatorPaths)

        // assert
        XCTAssertEqual(
            result,
            CocoapodsDependencies(
                repos: ["a"],
                dependencies: [.cdn(name: "a", requirement: .atLeast("0"), source: "source")],
                defaultForceLinking: nil,
                forceLinking: [:]
            )
        )
    }

    func testCocoapodsDependenciesMapperWithoutLocalPodspecsWithPath() throws {
        // arrange
        let temporaryPath = try temporaryPath()

        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)

        var result: ProjectDescription.CocoapodsDependencies = .init(
            repos: ["a"],
            dependencies: [
                .cdn(name: "a", requirement: .atLeast("0"), source: "source"),
                .path(name: "b", path: "b-path"),
            ]
        )

        // act
        try result.resolvePaths(generatorPaths: generatorPaths)

        // assert
        XCTAssertEqual(
            result,
            CocoapodsDependencies(
                repos: ["a"],
                dependencies: [
                    .cdn(name: "a", requirement: .atLeast("0"), source: "source"),
                    .path(name: "b", path: "\(temporaryPath.pathString)/b-path"),
                ],
                defaultForceLinking: nil,
                forceLinking: [:]
            )
        )
    }

    func testCocoapodsDependenciesMapperWithLocalPodspecsWithPath() throws {
        // arrange
        let temporaryPath = try temporaryPath()
        try createFiles([
            "Podspec1.podspec",
            "Podspec2.podspec",
            "inner/dir/BBBpodspec.podspec.json",
            "inner/dir/BBBpodspec3.podspec",
        ])

        let output: [CocoapodsDependencies.Dependency] = [
            .cdn(name: "a", requirement: .atLeast("0"), source: "source"),
            .path(name: "b", path: "\(temporaryPath.pathString)/b-path"),
            .path(name: "Podspec1", path: "\(temporaryPath.pathString)"),
            .path(name: "Podspec2", path: "\(temporaryPath.pathString)"),
            .path(name: "BBBpodspec", path: "\(temporaryPath.pathString)/inner/dir"),
            .path(name: "BBBpodspec3", path: "\(temporaryPath.pathString)/inner/dir"),
        ]

        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)

        var result: ProjectDescription.CocoapodsDependencies = .init(
            repos: ["a"],
            dependencies: [
                .cdn(name: "a", requirement: .atLeast("0"), source: "source"),
                .path(name: "b", path: "b-path"),
            ],
            localPodspecs: [
                ".": ["Podspec1.podspec", "Podspec2.podspec"],
                "inner/dir": ["BBB*.podspec*"],
            ]
        )

        // act
        try result.resolvePaths(generatorPaths: generatorPaths)

        // assert
        XCTAssertEqual(result.repos, ["a"])
        XCTAssertEqual(result.dependencies.count, output.count)
        XCTAssertTrue(result.dependencies.contains(where: { $0 == output[0] }))
        XCTAssertTrue(result.dependencies.contains(where: { $0 == output[1] }))
        XCTAssertTrue(result.dependencies.contains(where: { $0 == output[2] }))
        XCTAssertTrue(result.dependencies.contains(where: { $0 == output[3] }))
        XCTAssertTrue(result.dependencies.contains(where: { $0 == output[4] }))
        XCTAssertTrue(result.dependencies.contains(where: { $0 == output[5] }))
    }
    
    func testCocoapodsDependenciesMapperWithForcedLinking() throws {
        // arrange
        let temporaryPath = try temporaryPath()

        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)

        var result: ProjectDescription.CocoapodsDependencies = .init(
            repos: [],
            dependencies: [],
            forceLinking: ["a": .static]
        )

        // act
        try result.resolvePaths(generatorPaths: generatorPaths)

        // assert
        XCTAssertEqual(
            result,
            CocoapodsDependencies(
                repos: [],
                dependencies: [],
                defaultForceLinking: nil,
                forceLinking: ["a": .static]
            )
        )
    }
    
    func testCocoapodsDependenciesMapperWithBaseForcedLinking() throws {
        // arrange
        let temporaryPath = try temporaryPath()

        let generatorPaths = GeneratorPaths(manifestDirectory: temporaryPath)

        var result: ProjectDescription.CocoapodsDependencies = .init(
            repos: [],
            dependencies: [],
            defaultForceLinking: .static
        )

        // act
        try result.resolvePaths(generatorPaths: generatorPaths)

        // assert
        XCTAssertEqual(
            result,
            CocoapodsDependencies(
                repos: [],
                dependencies: [],
                defaultForceLinking: .static,
                forceLinking: [:]
            )
        )
    }

}
