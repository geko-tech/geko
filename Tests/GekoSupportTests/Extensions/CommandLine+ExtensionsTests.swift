import Foundation
import XCTest

@testable import GekoSupport

final class CommandLineExtensionsTests: XCTestCase {
    func test_filterTopLevelArguments_returnsCorrectArguments() {
        // Given
        let args = ["geko", "--force", "--verbose", "fetch", "-r"]

        // When
        let result = CommandLine.filterTopLevelArguments(from: args)

        // Then
        XCTAssertEqual(result, ["--force", "--verbose"])
    }

    func test_filterSubcommandArguments_returnsCorrectArguments() {
        // Given
        let args = ["geko", "--force", "--verbose", "fetch", "-r"]

        // When
        let result = CommandLine.filterSubcommandArguments(from: args)

        // Then
        XCTAssertEqual(result, ["fetch", "-r"])
    }

    func test_filterSubcommandArguments_returnsEmptyArguments() {
        // Given
        let args = ["geko", "--help"]

        // When
        let result = CommandLine.filterSubcommandArguments(from: args)

        // Then
        XCTAssertEqual(result, [])
    }
}
