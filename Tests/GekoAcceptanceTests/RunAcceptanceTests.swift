#if os(macOS)

import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import GekoSupportTesting
import XcodeProj
import XCTest

final class RunAcceptanceTestCommandLineToolBasic: GekoAcceptanceTestCase {
    func test_command_line_tool_basic() async throws {
        try setUpFixture(.commandLineToolBasic)
        try await run(RunCommand.self, "CommandLineTool")
    }
}

#endif
