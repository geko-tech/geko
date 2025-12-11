import Foundation
import struct ProjectDescription.AbsolutePath
import XCTest

@testable import GekoLoader
@testable import GekoSupportTesting

final class ProjectDescriptionSearchPathsTests: GekoUnitTestCase {
    func test_paths_style() throws {
        // Given
        let libraryPaths: [AbsolutePath] = [
            "/path/to/geko/.build/debug/libProjectDescription.dylib",
            "/path/to/DerivedData/Debug/ProjectDescription.framework",
            "/path/to/DerivedData/Debug/PackageFrameworks/ProjectDescription.framework",
        ]

        // When
        let searchPaths = libraryPaths.map { ProjectDescriptionSearchPaths.paths(for: $0) }

        // Then
        XCTAssertEqual(searchPaths.map(\.style), [
            .commandLine,
            .xcode,
            .swiftPackageInXcode,
        ])
    }

    func test_paths_includeSearchPath() throws {
        // Given
        let libraryPaths: [AbsolutePath] = [
            "/path/to/geko/.build/debug/libProjectDescription.dylib",
            "/path/to/DerivedData/Debug/ProjectDescription.framework",
            "/path/to/DerivedData/Debug/PackageFrameworks/ProjectDescription.framework",
        ]
        
        var expectedResult = [
            "/path/to/DerivedData/Debug",
            "/path/to/DerivedData/Debug"
        ]
        #if compiler(>=6.0.0)
        expectedResult.append("/path/to/geko/.build/debug/Modules")
        #else
        expectedResult.append("/path/to/geko/.build/debug")
        #endif

        // When
        let searchPaths = libraryPaths.map { ProjectDescriptionSearchPaths.paths(for: $0) }
        
        // Then
        XCTAssertEqual(searchPaths.map { $0.includeSearchPath.pathString }.sorted(), expectedResult.sorted())
    }

    func test_paths_librarySearchPath() throws {
        // Given
        let libraryPaths: [AbsolutePath] = [
            "/path/to/geko/.build/debug/libProjectDescription.dylib",
            "/path/to/DerivedData/Debug/ProjectDescription.framework",
            "/path/to/DerivedData/Debug/PackageFrameworks/ProjectDescription.framework",
        ]

        // When
        let searchPaths = libraryPaths.map { ProjectDescriptionSearchPaths.paths(for: $0) }

        // Then
        XCTAssertEqual(searchPaths.map(\.librarySearchPath), [
            "/path/to/geko/.build/debug",
            "/path/to/DerivedData/Debug",
            "/path/to/DerivedData/Debug",
        ])
    }

    func test_paths_frameworkSearchPath() throws {
        // Given
        let libraryPaths: [AbsolutePath] = [
            "/path/to/geko/.build/debug/libProjectDescription.dylib",
            "/path/to/DerivedData/Debug/ProjectDescription.framework",
            "/path/to/DerivedData/Debug/PackageFrameworks/ProjectDescription.framework",
        ]

        // When
        let searchPaths = libraryPaths.map { ProjectDescriptionSearchPaths.paths(for: $0) }

        // Then
        XCTAssertEqual(searchPaths.map(\.frameworkSearchPath), [
            "/path/to/geko/.build/debug",
            "/path/to/DerivedData/Debug",
            "/path/to/DerivedData/Debug/PackageFrameworks",
        ])
    }
}
