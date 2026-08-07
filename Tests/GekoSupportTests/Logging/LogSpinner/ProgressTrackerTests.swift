import XCTest
@testable import GekoSupport

final class ProgressTrackerTests: XCTestCase {
    func test_register_reports_current_and_counts() throws {
        let subject = ProgressTracker(elements: ["One", "Two", "Three"])

        let first = try XCTUnwrap(subject.register("Two"))
        XCTAssertEqual(first.current, "Two")
        XCTAssertEqual(first.completedCount, 1)
        XCTAssertEqual(first.totalCount, 3)
        XCTAssertEqual(first.remainingCount, 2)

        let second = try XCTUnwrap(subject.register("One"))
        XCTAssertEqual(second.current, "One")
        XCTAssertEqual(second.completedCount, 2)
        XCTAssertEqual(second.totalCount, 3)
        XCTAssertEqual(second.remainingCount, 1)

        let third = try XCTUnwrap(subject.register("Three"))
        XCTAssertEqual(third.current, "Three")
        XCTAssertEqual(third.completedCount, 3)
        XCTAssertEqual(third.totalCount, 3)
        XCTAssertEqual(third.remainingCount, 0)
    }

    func test_register_returns_nil_for_unexpected_element_without_changing_progress() throws {
        let subject = ProgressTracker(elements: ["One", "Two"])

        XCTAssertNil(subject.register("Unknown"))

        let progress = try XCTUnwrap(subject.register("One"))
        XCTAssertEqual(progress.completedCount, 1)
        XCTAssertEqual(progress.totalCount, 2)
        XCTAssertEqual(progress.remainingCount, 1)
    }

    func test_register_returns_nil_when_element_was_already_completed() throws {
        let subject = ProgressTracker(elements: ["One", "Two"])

        XCTAssertNotNil(subject.register("One"))
        XCTAssertNil(subject.register("One"))

        let progress = try XCTUnwrap(subject.register("Two"))
        XCTAssertEqual(progress.completedCount, 2)
        XCTAssertEqual(progress.remainingCount, 0)
    }

    func test_duplicate_expected_elements_are_counted_once() throws {
        let subject = ProgressTracker(elements: ["One", "One", "Two"])

        let progress = try XCTUnwrap(subject.register("One"))

        XCTAssertEqual(progress.totalCount, 2)
        XCTAssertEqual(progress.completedCount, 1)
        XCTAssertEqual(progress.remainingCount, 1)
    }

    func test_register_returns_nil_when_no_elements_are_expected() {
        let subject = ProgressTracker<String>(elements: [])

        XCTAssertNil(subject.register("One"))
    }
}
