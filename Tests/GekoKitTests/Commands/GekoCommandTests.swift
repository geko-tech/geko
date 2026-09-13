import XCTest

@testable import GekoKit

final class GekoCommandTests: XCTestCase {
    func test_process_arguments_removes_global_structured_output_flags() {
        let arguments = [
            "geko",
            "--structured",
            "--include-build-warnings",
            "build",
            "App",
        ]

        let result = GekoCommand.processArguments(arguments)

        XCTAssertEqual(result, ["geko", "build", "App"])
    }

    func test_process_arguments_preserves_scaffold_list_json_flag() {
        let arguments = ["geko", "scaffold", "list", "--json"]

        let result = GekoCommand.processArguments(arguments)

        XCTAssertEqual(result, arguments)
    }
}
