import Foundation
import GekoCore
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
import XCTest
@testable import GekoCoreTesting
@testable import GekoGenerator
@testable import GekoSupportTesting

final class CreateDraftFilesProjectMapperTests: GekoUnitTestCase {
    var subject: CreateDraftFilesProjectMapper!

    override public func setUp() {
        super.setUp()
        subject = CreateDraftFilesProjectMapper()
    }

    override public func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_map_returns_sideEffectsToCreateFiles() throws {
        // Given
        let projectA = Project.test(
            path: "/projectA",
            targets: [
                Target.test(preCreatedFiles: [
                    "Dummy/Dummy.swift",
                    "Dummy1.swift",
                    "DummyDir"
                ])
            ]
        )

        // When
        var project = projectA
        var sideTable = ProjectSideTable()
        let sideEffects = try subject.map(project: &project, sideTable: &sideTable)

        // Then
        let projectDir = projectA.path

        XCTAssertEqual(sideEffects, [
            .file(.init(path: projectDir.appending(component: "Dummy").appending(component: "Dummy.swift"), state: .present)),
            .file(.init(path: projectDir.appending(component: "Dummy1.swift"), state: .present)),
            .directory(.init(path: projectDir.appending(component: "DummyDir"), state: .present)),
        ])

        XCTAssertEqual(
            project.targets[0].sources,
            [
                SourceFiles(paths: [
                    projectDir.appending(components: ["Dummy", "Dummy.swift"]),
                    projectDir.appending(components: ["Dummy1.swift"])
                ])
            ]
        )
    }
}

