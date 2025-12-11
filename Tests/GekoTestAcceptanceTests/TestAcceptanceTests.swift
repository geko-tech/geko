import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import XCTest

/// Test projects using geko test
final class TestAcceptanceTests: GekoAcceptanceTestCase {
    func test_with_app_with_framework_and_tests() async throws {
        try setUpFixture(.appWithFrameworkAndTests)
        try await run(TestCommand.self)
        try await run(TestCommand.self, "App")
        try await run(TestCommand.self, "--test-targets", "FrameworkTests/FrameworkTests")
    }

    func test_with_app_with_test_plan() async throws {
        try setUpFixture(.appWithTestPlan)
        try await run(TestCommand.self)
        try await run(TestCommand.self, "App", "--test-plan", "All")
    }
}
