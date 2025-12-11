import Foundation
import struct ProjectDescription.AbsolutePath
import XCTest
@testable import GekoSupport
@testable import GekoSupportTesting

final class ProcessResultTests: GekoUnitTestCase {
    func test_command_returns_the_right_command_when_xcrun() {
        // Given
        let subject = ProcessResult(
            arguments: ["/usr/bin/xcrun", "swiftc"],
            environment: [:],
            exitStatus: .terminated(code: 1),
            output: .failure(TestError("error")),
            stderrOutput: .failure(TestError("error"))
        )

        // When
        let got = subject.command()

        // Then
        XCTAssertEqual(got, "swiftc")
    }
}
