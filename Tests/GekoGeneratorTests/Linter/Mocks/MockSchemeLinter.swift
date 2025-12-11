import Foundation
import GekoCore
import GekoGraph
import GekoGraphTesting
import GekoSupport
@testable import GekoGenerator

class MockSchemeLinter: SchemeLinting {
    func lint(project _: Project) -> [LintingIssue] {
        []
    }
}
