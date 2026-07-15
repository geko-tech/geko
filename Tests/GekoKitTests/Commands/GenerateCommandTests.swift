import XCTest

@testable import GekoKit

final class GenerateCommandTests: XCTestCase {
    func test_parse_acceptsPlanOption() throws {
        let command = try GenerateCommand.parse(["--plan", "focus.plan"])

        XCTAssertEqual(command.options.plan, "focus.plan")
        XCTAssertEqual(command.options.sources, [])
    }

    func test_parse_preservesPositionalSources() throws {
        let command = try GenerateCommand.parse(["App", "Feature.*"])

        XCTAssertNil(command.options.plan)
        XCTAssertEqual(command.options.sources, ["App", "Feature.*"])
    }
}
