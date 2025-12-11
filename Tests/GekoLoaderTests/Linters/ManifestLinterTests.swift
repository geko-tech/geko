import ProjectDescription
import GekoCore
import GekoSupport
import XCTest

@testable import GekoLoader

class ManifestLinterTests: XCTestCase {
    var subject: ManifestLinter!

    override func setUp() {
        super.setUp()
        subject = ManifestLinter()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_lint_project_duplicateTargetNames() throws {
        // Given
        let targetA = Target.manifestTest(name: "A")
        let targetADuplicated = Target.manifestTest(name: "A")
        let targetB = Target.manifestTest(name: "B")
        let project = Project.manifestTest(targets: [targetA, targetADuplicated, targetB])

        // When
        let results = subject.lint(project: project)

        // Then
        XCTAssertTrue(results.contains(LintingIssue(
            reason: "The target 'A' is declared multiple times within 'Project' project.",
            severity: .error
        )))
    }
}
