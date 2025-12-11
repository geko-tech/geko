import Foundation
import ProjectDescription
import XCTest

@testable import GekoSupport
@testable import GekoSupportTesting

final class StringExtrasTests: GekoUnitTestCase {
    func test_camelized() {
        // Given
        let subject = "Framework-iOSResources"

        // When
        let got = subject.camelized

        // Then
        XCTAssertEqual(got, "frameworkIOSResources")
    }

    func test_camelized_edge_cases() {
        // Given
        let subject = "_1Flow"

        // When
        let got = subject.camelized

        // Then
        XCTAssertEqual(got, "_1Flow")
    }

    func test_to_valid_swift_identifier_starting_with_lowercase_letter() {
        // Given
        let subject = "classname"

        // When
        let got = subject.toValidSwiftIdentifier()

        // Then
        XCTAssertEqual(got, "Classname")
    }

    func test_to_valid_swift_identifier_string_starting_with_numbers() {
        // Given
        let subject = "123invalidName"

        // When
        let got = subject.toValidSwiftIdentifier()

        // Then
        XCTAssertEqual(got, "_123invalidName")
    }

    func test_to_valid_swift_identifier_string_with_special_characters() {
        // Given
        let subject = "class$name"

        // When
        let got = subject.toValidSwiftIdentifier()

        // Then
        XCTAssertEqual(got, "ClassName")
    }

    func test_to_valid_swift_identifier_string_is_already_a_valid_swift_identifier() {
        // Given
        let subject = "ValidClassName"

        // When
        let got = subject.toValidSwiftIdentifier()

        // Then
        XCTAssertEqual(got, "ValidClassName")
    }

    func test_string_doesnt_match_GitURL_regex() {
        // Given
        let stringToEvaluate = "not a url string"

        // When
        let result = stringToEvaluate.isGitURL

        // Then
        XCTAssertFalse(result)
    }

    func test_string_does_match_http_GitURL_with_branch_regex() {
        // Given
        let stringToEvaluate = "https://github.com/geko-tech/ExampleGekoTemplate.git@develop"

        // When
        let result = stringToEvaluate.isGitURL

        // Then
        XCTAssertTrue(result)
    }

    func test_string_does_match_http_GitURL_without_branch_regex() {
        // Given
        let stringToEvaluate = "https://github.com/geko-tech/ExampleGekoTemplate.git"

        // When
        let result = stringToEvaluate.isGitURL

        // Then
        XCTAssertTrue(result)
    }

    func test_string_does_match_ssh_GitURL_with_branch_regex() {
        // Given
        let stringToEvaluate = "git@github.com:user/repo.git@develop"

        // When
        let result = stringToEvaluate.isGitURL

        // Then
        XCTAssertTrue(result)
    }

    func test_string_does_match_ssh_GitURL_without_branch_regex() {
        // Given
        let stringToEvaluate = "git@github.com:user/repo.git"

        // When
        let result = stringToEvaluate.isGitURL

        // Then
        XCTAssertTrue(result)
    }
}

final class StringsArrayTests: GekoUnitTestCase {
    func test_listed_when_no_elements() {
        // Given
        let list: [String] = []

        // When
        let got = list.listed()

        // Then
#if os(macOS)
        XCTAssertEqual(got, "")
#else
        XCTAssertEqual(got, "[]")
#endif
    }

    func test_listed_when_only_one_element() {
        // Given
        let list = ["App"]

        // When
        let got = list.listed()

        // Then
#if os(macOS)
        XCTAssertEqual(got, "App")
#else
        XCTAssertEqual(got, "[\"App\"]")
#endif
    }

    func test_listed_when_two_elements() {
        // Given
        let list = ["App", "Tests"]

        // When
        let got = list.listed()

        // Then
#if os(macOS)
        XCTAssertEqual(got, "App and Tests")
#else
        XCTAssertEqual(got, ##"["App", "Tests"]"##)
#endif
    }

    func test_listed_when_more_than_two_elements() {
        // Given
        let list = ["App", "Tests", "Framework"]

        // When
        let got = list.listed()

        // Then
#if os(macOS)
        XCTAssertEqual(got, "App, Tests, and Framework")
#else
        XCTAssertEqual(got, ##"["App", "Tests", "Framework"]"##)
#endif
    }
}
