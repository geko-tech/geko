import Foundation
import XCTest

@testable import GekoSupport

final class CommandLineExtensionsTests: XCTestCase {
    func test_filterTopLevelArguments_returnsCorrectArguments() {
        // Given
        var args = ["geko", "--force", "--verbose", "fetch", "-r"]

        // When
        var result = CommandLine.filterTopLevelArguments(from: args)

        // Then
        XCTAssertEqual(result, ["--force", "--verbose"])
    }

    func test_filterSubcommandArguments_returnsCorrectArguments() {
        // Given
        var args = ["geko", "--force", "--verbose", "fetch", "-r"]

        // When
        var result = CommandLine.filterSubcommandArguments(from: args)

        // Then
        XCTAssertEqual(result, ["fetch", "-r"])
    }

    func test_filterSubcommandArguments_returnsEmptyArguments() {
        // Given
        var args = ["geko", "--help"]

        // When
        var result = CommandLine.filterSubcommandArguments(from: args)

        // Then
        XCTAssertEqual(result, [])
    }
}
