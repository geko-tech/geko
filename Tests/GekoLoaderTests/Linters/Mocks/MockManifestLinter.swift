import Foundation
import ProjectDescription
import GekoCore
import GekoSupport
@testable import GekoLoader

class MockManifestLinter: ManifestLinting {
    var stubLintProject: [LintingIssue] = []
    func lint(project _: ProjectDescription.Project) -> [LintingIssue] {
        stubLintProject
    }
}
