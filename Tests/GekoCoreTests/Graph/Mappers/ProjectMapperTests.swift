import Foundation
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest

@testable import GekoSupportTesting

final class TargetProjectMapperTests: XCTestCase {
    func test_map_project() throws {
        // Given
        let targetMapper = TargetMapper {
            var updated = $0
            updated.name = "Updated_\($0.name)"
            return (updated, [])
        }
        let subject = TargetProjectMapper(mapper: targetMapper)
        let targetA = Target.test(name: "A")
        let targetB = Target.test(name: "B")
        let project = Project.test(targets: [targetA, targetB])

        // When
        var updatedProject = project
        var sideTable = ProjectSideTable()
        let sideEffects = try subject.map(project: &updatedProject, sideTable: &sideTable)

        // Then
        XCTAssertEqual(updatedProject.targets.map(\.name), [
            "Updated_A",
            "Updated_B",
        ])
        XCTAssertTrue(sideEffects.isEmpty)
    }

    func test_map_sideEffects() throws {
        // Given
        let targetMapper = TargetMapper {
            var updated = $0
            updated.name = "Updated_\($0.name)"
            return (updated, [.file(.init(path: try! AbsolutePath(validating: "/Targets/\($0.name).swift")))])
        }
        let subject = TargetProjectMapper(mapper: targetMapper)
        let targetA = Target.test(name: "A")
        let targetB = Target.test(name: "B")
        var project = Project.test(targets: [targetA, targetB])

        // When
        var sideTable = ProjectSideTable()
        let sideEffects = try subject.map(project: &project, sideTable: &sideTable)

        // Then
        XCTAssertEqual(sideEffects, [
            .file(.init(path: try AbsolutePath(validating: "/Targets/A.swift"))),
            .file(.init(path: try AbsolutePath(validating: "/Targets/B.swift"))),
        ])
    }

    // MARK: - Helpers

    private class TargetMapper: TargetMapping {
        let mapper: (Target) -> (Target, [SideEffectDescriptor])
        init(mapper: @escaping (Target) -> (Target, [SideEffectDescriptor])) {
            self.mapper = mapper
        }

        func map(target: Target) throws -> (Target, [SideEffectDescriptor]) {
            mapper(target)
        }
    }
}

final class SequentialProjectMapperTests: XCTestCase {
    func test_map_project() throws {
        // Given
        let mapper1 = ProjectMapper { project, _ in
            project = Project.test(name: "Update1_\(project.name)")
            return []
        }
        let mapper2 = ProjectMapper { project, _ in
            project = Project.test(name: "Update2_\(project.name)")
            return []
        }
        let subject = SequentialProjectMapper(mappers: [mapper1, mapper2])
        let project = Project.test(name: "Project")

        // When
        var updatedProject = project
        var sideTable = ProjectSideTable()
        let sideEffects = try subject.map(project: &updatedProject, sideTable: &sideTable)

        // Then
        XCTAssertEqual(updatedProject.name, "Update2_Update1_Project")
        XCTAssertTrue(sideEffects.isEmpty)
    }

    func test_map_sideEffects() throws {
        // Given
        let mapper1 = ProjectMapper { project, _ in
            project = Project.test(name: "Update1_\(project.name)")
            return [.command(.init(command: ["command 1"]))]
        }
        let mapper2 = ProjectMapper { project, _ in
            project = Project.test(name: "Update2_\(project.name)")
            return [.command(.init(command: ["command 2"]))]
        }
        let subject = SequentialProjectMapper(mappers: [mapper1, mapper2])
        var project = Project.test(name: "Project")

        // When
        var sideTable = ProjectSideTable()
        let sideEffects = try subject.map(project: &project, sideTable: &sideTable)

        // Then
        XCTAssertEqual(sideEffects, [
            .command(.init(command: ["command 1"])),
            .command(.init(command: ["command 2"])),
        ])
    }

    // MARK: - Helpers

    private class ProjectMapper: ProjectMapping {
        let mapper: (inout Project, inout ProjectSideTable) -> [SideEffectDescriptor]
        init(mapper: @escaping (inout Project, inout ProjectSideTable) -> [SideEffectDescriptor]) {
            self.mapper = mapper
        }

        func map(project: inout Project, sideTable: inout ProjectSideTable) throws -> [SideEffectDescriptor] {
            mapper(&project, &sideTable)
        }
    }
}
