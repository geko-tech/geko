import GekoGraph
import ProjectDescription
import XCTest

final class IDETemplateMacrosTests: XCTestCase {
    func test_removing_leading_comment_slashes() throws {
        // Given
        let fileHeader = "// Some template"
        let templateMacros = FileHeaderTemplate(fileHeader: fileHeader)

        // When
        let templateContent = try templateMacros.normalize()

        // Then
        XCTAssertEqual(" Some template", templateContent)
    }

    func test_space_preservation_if_leading_comment_slashes_are_present() throws {
        // Given
        let fileHeader = "//Some template"
        let templateMacros = FileHeaderTemplate(fileHeader: fileHeader)

        // When
        let templateContent = try templateMacros.normalize()

        // Then
        XCTAssertEqual("Some template", templateContent)
    }

    func test_removing_trailing_newline() throws {
        // Given
        let fileHeader = "Some template\n"
        let templateMacros = FileHeaderTemplate(fileHeader: fileHeader)

        // When
        let templateContent = try templateMacros.normalize()

        // Then
        XCTAssertEqual(" Some template", templateContent)
    }

    func test_inserting_leading_space() throws {
        // Given
        let fileHeader = "Some template"
        let templateMacros = FileHeaderTemplate(fileHeader: fileHeader)

        // When
        let templateContent = try templateMacros.normalize()

        // Then
        XCTAssertEqual(" Some template", templateContent)
    }

    func test_not_inserting_leading_space_if_already_present() throws {
        // Given
        let fileHeader = " Some template"
        let templateMacros = FileHeaderTemplate(fileHeader: fileHeader)

        // When
        let templateContent = try templateMacros.normalize()

        // Then
        XCTAssertEqual(" Some template", templateContent)
    }

    func test_not_inserting_leading_space_if_starting_with_newline() throws {
        // Given
        let fileHeader = "\nSome template"
        let templateMacros = FileHeaderTemplate(fileHeader: fileHeader)

        // When
        let templateContent = try templateMacros.normalize()

        // Then
        XCTAssertEqual("\nSome template", templateContent)
    }
}
