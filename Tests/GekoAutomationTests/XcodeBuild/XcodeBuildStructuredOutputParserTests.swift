import Foundation
import struct ProjectDescription.RelativePath
import XCTest

@testable import GekoAutomation
@testable import GekoSupportTesting

final class XcodeBuildStructuredOutputParserTests: XCTestCase {
    func testSuccessfulBuild() throws {
        let output = try parseFixture("success", succeeded: true)

        XCTAssertEqual(output.action, .build)
        XCTAssertEqual(output.scheme, "MainApp")
        XCTAssertEqual(output.status, .success)
        XCTAssertEqual(output.duration, 2.5)
        XCTAssertNil(output.warningCount)
        XCTAssertNil(output.errors)
        XCTAssertNil(output.warnings)
        XCTAssertNil(output.linkerErrors)
        XCTAssertNil(output.testFailures)
    }

    func testSwiftCompilerError() throws {
        let output = try parseFixture("swift-error", succeeded: false)

        XCTAssertEqual(output.status, .failed)
        XCTAssertEqual(output.errors?.count, 1)
        XCTAssertEqual(output.errors?.first?.file, "/tmp/XcodeBuildOutputFixture/macOS/macOS.swift")
        XCTAssertEqual(output.errors?.first?.line, 7)
        XCTAssertEqual(output.errors?.first?.message, "cannot find 'missingValue' in scope")
    }

    func testWarningIsCountedButDetailsAreExcludedByDefault() throws {
        let output = try parseFixture("warning", succeeded: true)

        XCTAssertEqual(output.status, .success)
        XCTAssertEqual(output.warningCount, 1)
        XCTAssertNil(output.warnings)
    }

    func testWarningDetailsAreIncludedWhenEnabled() throws {
        let output = try parseFixture(
            "warning",
            succeeded: true,
            includeWarnings: true
        )

        XCTAssertEqual(output.status, .success)
        XCTAssertEqual(output.warningCount, 1)
        XCTAssertEqual(output.warnings?.count, 1)
        XCTAssertEqual(output.warnings?.first?.file, "/tmp/XcodeBuildOutputFixture/macOS/macOS.swift")
        XCTAssertEqual(output.warnings?.first?.line, 7)
        XCTAssertEqual(
            output.warnings?.first?.message,
            "initialization of immutable value 'unusedValue' was never used; consider replacing with assignment to '_' or removing it"
        )
        XCTAssertEqual(output.warnings?.first?.type, "compile")
    }

    func testLinkerError() throws {
        let output = try parseFixture("linker-error", succeeded: false)

        XCTAssertEqual(output.status, .failed)
        XCTAssertEqual(output.linkerErrors?.count, 1)
        XCTAssertEqual(output.linkerErrors?.first?.symbol, "_geko_missing_symbol")
        XCTAssertEqual(output.linkerErrors?.first?.architecture, "arm64")
        XCTAssertEqual(output.linkerErrors?.first?.referencedFrom, "macOS.o")
    }

    func testTestFailure() throws {
        let output = try parseFixture("test-failure", succeeded: false, action: .test)

        XCTAssertEqual(output.status, .failed)
        XCTAssertEqual(output.testFailures?.count, 1)
        XCTAssertEqual(output.testFailures?.first?.test, "FixtureTests.FixtureLibraryTests testFixtureValue")
        XCTAssertEqual(output.testFailures?.first?.file, "/tmp/XcodeBuildOutputFixture/Tests/FixtureLibraryTests.swift")
        XCTAssertEqual(output.testFailures?.first?.line, 5)
        XCTAssertEqual(output.testFailures?.first?.message, "XCTAssertEqual failed: (\"1\") is not equal to (\"2\")")
        XCTAssertEqual(output.testFailures?.first?.duration, 0.548)
    }

    func testSuccessfulProcessIsSuccessfulWithoutATerminalBuildMarker() {
        let start = Date(timeIntervalSince1970: 100)
        var parser = XcodeBuildStructuredOutputParser(action: .build, scheme: "MainApp", startTime: start)

        let output = parser.finish(succeeded: true, endTime: start)

        XCTAssertEqual(output.status, .success)
    }

    func testRoundsDurationToHundredthsOfASecond() {
        let start = Date(timeIntervalSince1970: 100)
        var parser = XcodeBuildStructuredOutputParser(action: .build, scheme: "MainApp", startTime: start)

        let output = parser.finish(
            succeeded: true,
            endTime: start.addingTimeInterval(12.3456)
        )

        XCTAssertEqual(output.duration, 12.35, accuracy: 0.0001)
    }

    func testFailedProcessIsFailedEvenWhenParsedOutputLooksSuccessful() throws {
        let output = try parseFixture("success", succeeded: false)

        XCTAssertEqual(output.status, .failed)
    }

    private func parseFixture(
        _ name: String,
        succeeded: Bool,
        action: XcodeBuildAction = .build,
        includeWarnings: Bool = false
    ) throws -> XcodeBuildInvocationOutput {
        let path = fixturePath(
            path: try RelativePath(validating: "XcodeBuild/\(name).log")
        )
        let contents = try String(contentsOf: path.asURL, encoding: .utf8)
        let start = Date(timeIntervalSince1970: 100)
        var parser = XcodeBuildStructuredOutputParser(
            action: action,
            scheme: "MainApp",
            includeWarnings: includeWarnings,
            startTime: start
        )
        contents.enumerateLines { line, _ in parser.feed(line) }
        return parser.finish(
            succeeded: succeeded,
            endTime: start.addingTimeInterval(2.5)
        )
    }
}
