import GekoGraph
import GekoGraphTesting
import GekoSupport
import GekoSupportTesting
import ProjectDescription
import XCTest
@testable import GekoGenerator

final class GenerateDummySourceFileProjectMapperTests: GekoUnitTestCase {
    func testMap_whenSPMProject_doesNotGenerateDummySource() throws {
        var project = Project.test(
            targets: [Target.test(name: "SomeFramework", product: .staticFramework)],
            projectType: .spm
        )
        var sideTable = ProjectSideTable()

        let sideEffects = try GenerateDummySourceFileProjectMapper().map(
            project: &project,
            sideTable: &sideTable
        )

        XCTAssertTrue(sideEffects.isEmpty)
        XCTAssertTrue(project.targets[0].sources.isEmpty)
    }

    func testMap_whenNonSPMProjectHasNoSources_generatesDummySource() throws {
        var project = Project.test(
            targets: [Target.test(name: "EmptyTarget")]
        )
        var sideTable = ProjectSideTable()

        let sideEffects = try GenerateDummySourceFileProjectMapper().map(
            project: &project,
            sideTable: &sideTable
        )

        XCTAssertEqual(sideEffects.count, 1)
        XCTAssertEqual(project.targets[0].sources.count, 1)
        XCTAssertEqual(project.targets[0].sources[0].paths.count, 1)
        XCTAssertEqual(project.targets[0].sources[0].paths[0].basename, "EmptyTargetDummy.swift")
    }
}
