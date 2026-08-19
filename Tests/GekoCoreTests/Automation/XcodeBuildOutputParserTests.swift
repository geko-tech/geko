import XCTest
@testable import GekoCore

final class XcodeBuildOutputParserTests: XCTestCase {
    private var subject: XcodeBuildOutputParser!

    override func setUp() {
        super.setUp()
        subject = XcodeBuildOutputParser()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_parse_returns_compilation_started_for_compile_swift() {
        let line = "CompileSwift normal arm64 Sources/App.swift (in target 'App' from project 'Application')"

        XCTAssertEqual(
            subject.parse(line: line),
            .targetCompilationStarted(targetName: "App")
        )
    }

    func test_parse_returns_compilation_started_for_compile_c() {
        let line = "CompileC /tmp/App.o Sources/App.m normal arm64 objective-c (in target 'App' from project 'Application')"

        XCTAssertEqual(
            subject.parse(line: line),
            .targetCompilationStarted(targetName: "App")
        )
    }

    func test_parse_returns_process_info_plist_event() {
        let line = "ProcessInfoPlistFile /tmp/App.app/Info.plist Info.plist (in target 'App' from project 'Application')"

        XCTAssertEqual(
            subject.parse(line: line),
            .processInfoPlistFile(targetName: "App")
        )
    }

    func test_parse_returns_target_touched_event() {
        let line = "Touch /tmp/App.app (in target 'App' from project 'Application')"

        XCTAssertEqual(
            subject.parse(line: line),
            .targetTouched(targetName: "App")
        )
    }

    func test_parse_trims_leading_and_trailing_whitespace() {
        let line = "  \tCompileSwift normal arm64 Sources/App.swift (in target 'App' from project 'Application')  "

        XCTAssertEqual(
            subject.parse(line: line),
            .targetCompilationStarted(targetName: "App")
        )
    }

    func test_parse_preserves_spaces_in_target_name() {
        let line = "Touch /tmp/App.app (in target 'App Extension' from project 'Application')"

        XCTAssertEqual(
            subject.parse(line: line),
            .targetTouched(targetName: "App Extension")
        )
    }

    func test_parse_returns_nil_for_unknown_operation() {
        let line = "Ld /tmp/App normal (in target 'App' from project 'Application')"

        XCTAssertNil(subject.parse(line: line))
    }

    func test_parse_returns_nil_without_target_context() {
        XCTAssertNil(subject.parse(line: "CompileSwift normal arm64 Sources/App.swift"))
    }

    func test_parse_returns_nil_when_target_context_is_not_at_end_of_line() {
        let line = "Touch /tmp/App.app (in target 'App' from project 'Application') trailing output"

        XCTAssertNil(subject.parse(line: line))
    }

    func test_parse_returns_nil_for_empty_line() {
        XCTAssertNil(subject.parse(line: ""))
    }
}
