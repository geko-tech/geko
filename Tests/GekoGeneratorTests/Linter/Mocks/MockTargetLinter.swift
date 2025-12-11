import Foundation
import GekoCore
import GekoGraph
import GekoGraphTesting
import GekoSupport
@testable import GekoGenerator

class MockTargetLinter: TargetLinting {
    func lint(target _: Target) -> [LintingIssue] {
        []
    }
}
