import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport
import XCTest

@testable import GekoLoader
@testable import GekoSupportTesting

final class DependencyManifestMapperTests: GekoUnitTestCase {
    func test_from_when_external_xcframework() throws {
        // Given
        var dependency = ProjectDescription.TargetDependency.external(name: "library")
        let generatorPaths = GeneratorPaths(manifestDirectory: try AbsolutePath(validating: "/"))

        // When
        var got: [TargetDependency] = []
        try dependency.resolvePaths(generatorPaths: generatorPaths)
        try dependency.resolveDependencies(
            into: &got,
            externalDependencies: ["library": [.xcframework(path: "/path.xcframework", status: .required)]]
        )

        // Then
        XCTAssertEqual(got.count, 1)
        guard case let .xcframework(path, status, _) = got[0] else {
            XCTFail("Dependency should be xcframework")
            return
        }
        XCTAssertEqual(path, "/path.xcframework")
        XCTAssertEqual(status, .required)
    }

    func test_from_when_external_project() throws {
        // Given
        var dependency = ProjectDescription.TargetDependency.external(name: "library")
        let generatorPaths = GeneratorPaths(manifestDirectory: try AbsolutePath(validating: "/"))

        // When
        var got: [TargetDependency] = []
        try dependency.resolvePaths(generatorPaths: generatorPaths)
        try dependency.resolveDependencies(
            into: &got,
            externalDependencies: ["library": [.project(target: "Target", path: "/Project")]]
        )

        // Then
        XCTAssertEqual(got.count, 1)
        guard case let .project(target, path, _, _) = got[0] else {
            XCTFail("Dependency should be project")
            return
        }
        XCTAssertEqual(target, "Target")
        XCTAssertEqual(path, "/Project")
    }

    func test_from_when_external_multiple() throws {
        // Given
        var dependency = ProjectDescription.TargetDependency.external(name: "library")
        let generatorPaths = GeneratorPaths(manifestDirectory: try AbsolutePath(validating: "/"))

        // When
        try dependency.resolvePaths(generatorPaths: generatorPaths)
        var got: [TargetDependency] = []
        try dependency.resolveDependencies(
            into: &got,
            externalDependencies: [
                "library": [
                    .xcframework(path: "/path.xcframework", status: .required),
                    .project(target: "Target", path: "/Project"),
                ],
            ]
        )

        // Then
        XCTAssertEqual(got.count, 2)
        guard case let .xcframework(frameworkPath, status, _) = got[0] else {
            XCTFail("First dependency should be xcframework")
            return
        }
        XCTAssertEqual(frameworkPath, "/path.xcframework")
        XCTAssertEqual(status, .required)

        guard case let .project(target, path, _, _) = got[1] else {
            XCTFail("Dependency should be project")
            return
        }
        XCTAssertEqual(target, "Target")
        XCTAssertEqual(path, "/Project")
    }

    func test_from_when_sdkLibrary() throws {
        // Given
        var dependency = ProjectDescription.TargetDependency.sdk(name: "c++", type: .library, status: .required)
        let generatorPaths = GeneratorPaths(manifestDirectory: try AbsolutePath(validating: "/"))

        // When
        var got: [TargetDependency] = []
        try dependency.resolvePaths(generatorPaths: generatorPaths)
        try dependency.resolveDependencies(into: &got, externalDependencies: [:])

        // Then
        XCTAssertEqual(got.count, 1)
        guard case let .sdk(name, _, status, _) = got[0] else {
            XCTFail("Dependency should be sdk")
            return
        }
        XCTAssertEqual(name, "libc++.tbd")
        XCTAssertEqual(status, .required)
    }

    func test_from_when_sdkFramework() throws {
        // Given
        var dependency = ProjectDescription.TargetDependency.sdk(name: "ARKit", type: .framework, status: .required)
        let generatorPaths = GeneratorPaths(manifestDirectory: try AbsolutePath(validating: "/"))

        // When
        var got: [TargetDependency] = []
        try dependency.resolvePaths(generatorPaths: generatorPaths)
        try dependency.resolveDependencies(into: &got, externalDependencies: [:])

        // Then
        XCTAssertEqual(got.count, 1)
        guard case let .sdk(name, _, status, _) = got[0] else {
            XCTFail("Dependency should be sdk")
            return
        }
        XCTAssertEqual(name, "ARKit.framework")
        XCTAssertEqual(status, .required)
    }
}
