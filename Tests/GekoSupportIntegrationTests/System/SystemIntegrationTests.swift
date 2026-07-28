import struct ProjectDescription.AbsolutePath
import XCTest
@testable import GekoSupport
@testable import GekoSupportTesting

final class SystemIntegrationTests: GekoTestCase {
    var subject: System!

    override func setUp() {
        super.setUp()
        subject = System()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_run_valid_command() {
        XCTAssertNoThrow(try subject.run(["ls"]))
    }

    func test_run_invalid_command() {
        XCTAssertThrowsError(try subject.run(["abcdef", "ghi"]))
    }

    func test_run_valid_command_that_returns_nonzero_exit() {
        XCTAssertThrowsError(try subject.run(["ls", "abcdefghi"]))
    }

    func test_capture_with_input_is_isolated_between_concurrent_processes() async throws {
        let inputs = (0..<20).map { index in
            String(repeating: "input-\(index)\n", count: 1000)
        }

        let outputs = try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, input) in inputs.enumerated() {
                group.addTask {
                    (index, try System().capture(["/bin/cat"], withInput: input))
                }
            }

            var outputs = Array(repeating: "", count: inputs.count)
            for try await (index, output) in group {
                outputs[index] = output
            }
            return outputs
        }

        XCTAssertEqual(outputs, inputs)
    }

    func sandbox(_ name: String, value: String, do block: () throws -> Void) rethrows {
        try? ProcessEnv.setVar(name, value: value)
        _ = try? block()
        try? ProcessEnv.unsetVar(name)
    }
}
