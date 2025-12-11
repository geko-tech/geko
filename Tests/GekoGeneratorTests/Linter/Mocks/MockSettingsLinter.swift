import Foundation
import GekoCore
import GekoGraph
import GekoGraphTesting
import GekoSupport
@testable import GekoGenerator

class MockSettingsLinter: SettingsLinting {
    func lint(project _: Project) -> [LintingIssue] {
        []
    }

    func lint(target _: Target) -> [LintingIssue] {
        []
    }
}
