import XCTest

@testable import GekoKit

final class GenerateCommandTests: XCTestCase {
    func test_parse_acceptsFocusPlanOption() throws {
        let command = try GenerateCommand.parse(["--focus-plan", "focus.plan"])

        XCTAssertFalse(command.cache)
        XCTAssertEqual(command.options.focusPlan, "focus.plan")
        XCTAssertEqual(command.options.sources, [])
    }

    func test_parse_preservesPackedManifestFlagAndPathOptions() throws {
        let command = try GenerateCommand.parse(["-fp", "FLAG", "/tmp/project"])

        XCTAssertEqual(command.manifestOptions.flags, ["FLAG"])
        XCTAssertEqual(command.options.path, "/tmp/project")
        XCTAssertNil(command.options.focusPlan)
    }

    func test_parse_acceptsCacheWithFocusPlanOption() throws {
        let command = try GenerateCommand.parse(["--cache", "--focus-plan", "focus.plan"])

        XCTAssertTrue(command.cache)
        XCTAssertEqual(command.options.focusPlan, "focus.plan")
        XCTAssertEqual(command.options.sources, [])
    }

    func test_parse_acceptsFocusPlanWithPositionalSources() throws {
        let command = try GenerateCommand.parse(["App", "--focus-plan", "focus.plan"])

        XCTAssertEqual(command.options.focusPlan, "focus.plan")
        XCTAssertEqual(command.options.sources, ["App"])
    }

    func test_parse_preservesPositionalSources() throws {
        let command = try GenerateCommand.parse(["App", "Feature.*"])

        XCTAssertNil(command.options.focusPlan)
        XCTAssertEqual(command.options.sources, ["App", "Feature.*"])
    }
}
