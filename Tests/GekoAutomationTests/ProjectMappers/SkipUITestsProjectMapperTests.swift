import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest

@testable import GekoAutomation
@testable import GekoCoreTesting
@testable import GekoSupportTesting

final class SkipUITestsProjectMapperTests: GekoUnitTestCase {
    private var subject: SkipUITestsProjectMapper!

    override func setUp() {
        super.setUp()
        subject = .init()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_prune_is_set_to_ui_targets() throws {
        // Given
        var project = Project.test(
            targets: [
                .test(name: "App", product: .app),
                .test(name: "UnitTests", product: .unitTests),
                .test(name: "UITests", product: .uiTests),
            ]
        )
        var sideTable = ProjectSideTable()

        // When
        let gotSideEffects = try subject.map(project: &project, sideTable: &sideTable)
        var expectedUITestsTarget = Target.test(name: "UITests", product: .uiTests)
        expectedUITestsTarget.prune = true
        XCTAssertEqual(
            project,
            Project.test(
                targets: [
                    .test(name: "App", product: .app),
                    .test(name: "UnitTests", product: .unitTests),
                    expectedUITestsTarget
                ]
            )
        )
        XCTAssertEmpty(gotSideEffects)
    }
}
