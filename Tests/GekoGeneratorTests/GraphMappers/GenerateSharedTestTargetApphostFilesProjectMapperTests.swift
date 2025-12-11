import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import XCTest
import ProjectDescription

@testable import GekoGenerator
@testable import GekoSupportTesting

final class GenerateSharedTestTargetApphostFilesProjectMapperTests: GekoUnitTestCase {
    private let derived = "Derived"
    private let sources = "Sources"

    func test_map_generatesFiles() throws {
        // Given
        let subject = GenerateSharedTestTargetApphostFilesProjectMapper(
            derivedDirectoryName: derived,
            sourcesDirectoryName: sources
        )

        let target = Target.test(name: "App", product: .app)
        let anotherTarget = Target.test(name: "Framework", product: .app)
        let projectPath = try temporaryPath().appending(component: "App")
        var project = Project.test(
            path: projectPath, name: "App", targets: [target, anotherTarget]
        )
        var sideTable = ProjectSideTable()
        sideTable.targets[target.name, default: .init()].flags.insert(.sharedTestTargetAppHost)

        // When
        let gotSideEffects = try subject.map(project: &project, sideTable: &sideTable)

        // Then
        let expectedTargetDerivedPath = projectPath.appending(components: [
            derived, target.name
        ])
        let expectedSourcePath = expectedTargetDerivedPath.appending(components: [
            sources, "main.swift"
        ])
        let expectedStoryboardPath = expectedTargetDerivedPath.appending(component: "LaunchScreen.storyboard")

        XCTAssertEqual(gotSideEffects.count, 2, "Mapper did not produce enough or made more than required amount of side effects")
        XCTAssertTrue(gotSideEffects.contains(where: {
            if case let .file(descriptor) = $0 {
                return descriptor.path == expectedSourcePath && descriptor.state == .present
            }
            return false
        }), "Mapper should return sideEffect with main.swift file. Got sideEffects: \(gotSideEffects)")
        XCTAssertTrue(gotSideEffects.contains(where: {
            if case let .file(descriptor) = $0 {
                return descriptor.path == expectedSourcePath && descriptor.state == .present
            }
            return false
        }), "Mapper should return sideEffect with LaunchScreen.storyboard file. Got sideEffects: \(gotSideEffects)")

        XCTAssertEqual(
            project.targets[0].sources,
            [SourceFiles(paths: [expectedSourcePath])],
            "App host target must contain main.swift file after mapper application."
        )
        XCTAssertEqual(
            project.targets[0].resources,
            [ResourceFileElement(path: expectedStoryboardPath)],
            "App host target must contain LaunchScreen.storyboard file after mapper application."
        )

        XCTAssertEqual(
            project.targets[1], anotherTarget,
            "Mapper should not modify targets which have no .sharedTestTargetAppHost flag"
        )
    }
}
