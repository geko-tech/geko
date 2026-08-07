import XCTest
@testable import GekoSupport

final class LineBufferTests: XCTestCase {
    func test_append_returns_complete_line() {
        var subject = LineBuffer()

        XCTAssertEqual(subject.append(Array("first\n".utf8)), ["first"])
        XCTAssertNil(subject.finish())
    }

    func test_append_returns_multiple_complete_lines() {
        var subject = LineBuffer()

        XCTAssertEqual(
            subject.append(Array("first\nsecond\nthird\n".utf8)),
            ["first", "second", "third"]
        )
        XCTAssertNil(subject.finish())
    }

    func test_append_keeps_incomplete_line_until_next_chunk() {
        var subject = LineBuffer()

        XCTAssertEqual(subject.append(Array("fir".utf8)), [])
        XCTAssertEqual(subject.append(Array("st\nsec".utf8)), ["first"])
        XCTAssertEqual(subject.append(Array("ond\n".utf8)), ["second"])
        XCTAssertNil(subject.finish())
    }

    func test_append_preserves_empty_lines() {
        var subject = LineBuffer()

        XCTAssertEqual(subject.append(Array("\nfirst\n\n".utf8)), ["", "first", ""])
    }

    func test_finish_returns_incomplete_final_line_and_clears_buffer() {
        var subject = LineBuffer()

        XCTAssertEqual(subject.append(Array("final line".utf8)), [])
        XCTAssertEqual(subject.finish(), "final line")
        XCTAssertNil(subject.finish())
    }

    func test_finish_returns_nil_for_empty_buffer() {
        var subject = LineBuffer()

        XCTAssertNil(subject.finish())
    }

    func test_append_handles_utf8_character_split_between_chunks() {
        var subject = LineBuffer()
        let bytes = Array("Привет\n".utf8)

        XCTAssertEqual(subject.append(Array(bytes.prefix(3))), [])
        XCTAssertEqual(subject.append(Array(bytes.dropFirst(3))), ["Привет"])
    }

    func test_append_keeps_content_after_last_newline_for_finish() {
        var subject = LineBuffer()

        XCTAssertEqual(subject.append(Array("first\nsecond".utf8)), ["first"])
        XCTAssertEqual(subject.finish(), "second")
    }
}
