import Foundation
import GekoCore
import GekoGraph
import ProjectDescription

@testable import GekoGenerator

public final class MockEnvironmentLinter: EnvironmentLinting {
    public var lintStub: [LintingIssue]?
    public var lintArgs: [Config] = []

    public init() {}

    public func lint(config: Config) throws -> [LintingIssue] {
        lintArgs.append(config)
        return lintStub ?? []
    }
}
