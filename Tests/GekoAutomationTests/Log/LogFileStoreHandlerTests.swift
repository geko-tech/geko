import Foundation
import struct ProjectDescription.AbsolutePath
import XCTest
@testable import GekoAutomation
@testable import GekoCore
@testable import GekoSupportTesting

final class LogFileStoreHandlerTests: GekoUnitTestCase {
    private var logDirectoryProvider: LogDirectoriesProviderSpy!
    private var logDateFormatter: LogDateFormatterStub!
    private var logRotator: LogRotatorSpy!
    private var subject: LogFileStoreHandler!

    override func setUp() {
        super.setUp()
        logDirectoryProvider = LogDirectoriesProviderSpy()
        logDateFormatter = LogDateFormatterStub()
        logRotator = LogRotatorSpy()
        subject = LogFileStoreHandler(
            fileHandler: fileHandler,
            logDirectoryProvider: logDirectoryProvider,
            logDateFormatter: logDateFormatter,
            logRotator: logRotator
        )
    }

    override func tearDown() {
        subject = nil
        logRotator = nil
        logDateFormatter = nil
        logDirectoryProvider = nil
        super.tearDown()
    }

    func test_createPath_creates_expected_raw_build_log() throws {
        let rootPath = try temporaryPath().appending(component: "logs")
        let date = Date(timeIntervalSince1970: 123)
        logDirectoryProvider.path = rootPath
        logDateFormatter.formattedDate = "formatted-date"

        let result = try subject.createPath(logFile: .rawBuildLog, date: date)

        let expected = rootPath.appending(components: ["formatted-date", "rawBuild.log"])
        XCTAssertEqual(result, expected)
        XCTAssertTrue(fileHandler.exists(expected))
        XCTAssertEqual(logDirectoryProvider.receivedCategories, [.buildLogs])
        XCTAssertEqual(logDateFormatter.receivedDates, [date])
        XCTAssertEqual(logRotator.invocations.count, 1)
        XCTAssertEqual(logRotator.invocations.first?.category, .buildLogs)
        XCTAssertEqual(logRotator.invocations.first?.maxLogs, 10)
    }

    func test_createPath_creates_expected_formatted_build_log() throws {
        let rootPath = try temporaryPath().appending(component: "logs")
        logDirectoryProvider.path = rootPath
        logDateFormatter.formattedDate = "formatted-date"

        let result = try subject.createPath(logFile: .buildLog, date: Date())

        let expected = rootPath.appending(components: ["formatted-date", "build.log"])
        XCTAssertEqual(result, expected)
        XCTAssertTrue(fileHandler.exists(expected))
    }

    func test_createPath_reuses_existing_log_folder() throws {
        let rootPath = try temporaryPath().appending(component: "logs")
        let logFolderPath = rootPath.appending(component: "formatted-date")
        try fileHandler.createFolder(logFolderPath)
        logDirectoryProvider.path = rootPath
        logDateFormatter.formattedDate = "formatted-date"

        let result = try subject.createPath(logFile: .buildLog, date: Date())

        XCTAssertEqual(result, logFolderPath.appending(component: "build.log"))
        XCTAssertTrue(fileHandler.exists(result))
    }

    func test_write_appends_lines_in_order() throws {
        let path = try makeLogPath(for: .buildLog)

        try subject.write("first line", logFile: .buildLog)
        try subject.write("second line", logFile: .buildLog)
        try subject.close(logFile: .buildLog)

        XCTAssertEqual(try fileHandler.readTextFile(path), "first line\nsecond line\n")
    }

    func test_write_keeps_raw_and_formatted_logs_separate() throws {
        let rawPath = try makeLogPath(for: .rawBuildLog)
        let formattedPath = try makeLogPath(for: .buildLog)

        try subject.write("raw", logFile: .rawBuildLog)
        try subject.write("formatted", logFile: .buildLog)
        try subject.close(logFile: .rawBuildLog)
        try subject.close(logFile: .buildLog)

        XCTAssertEqual(try fileHandler.readTextFile(rawPath), "raw\n")
        XCTAssertEqual(try fileHandler.readTextFile(formattedPath), "formatted\n")
    }

    func test_write_throws_when_file_handle_was_not_initialized() {
        XCTAssertThrowsError(try subject.write("line", logFile: .rawBuildLog)) { error in
            guard case let LogFileStoreHandlerError.fileHandleNotInitialized(logFile) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(logFile.rawValue, LogFile.rawBuildLog.rawValue)
        }
    }

    func test_fileHandleNotInitialized_error_has_expected_description_and_type() {
        let error = LogFileStoreHandlerError.fileHandleNotInitialized(.buildLog)

        XCTAssertEqual(
            error.description,
            "Attempted to write to an uninitialized fileHandle for file build.log. This is likely an internal error. Please report this issue."
        )
        XCTAssertEqual(error.type, .abort)
    }

    func test_close_does_nothing_when_file_handle_was_not_initialized() {
        XCTAssertNoThrow(try subject.close(logFile: .rawBuildLog))
    }

    private func makeLogPath(for logFile: LogFile) throws -> AbsolutePath {
        logDirectoryProvider.path = try temporaryPath().appending(component: "logs")
        logDateFormatter.formattedDate = "formatted-date"
        return try subject.createPath(logFile: logFile, date: Date())
    }
}

private final class LogDirectoriesProviderSpy: LogDirectoriesProviding {
    var path: AbsolutePath = .root
    private(set) var receivedCategories: [LogCategory] = []

    func logDirectory(for category: LogCategory) throws -> AbsolutePath {
        receivedCategories.append(category)
        return path
    }
}

private final class LogDateFormatterStub: LogDateFormatting {
    var formattedDate = "date"
    private(set) var receivedDates: [Date] = []

    func dateToString(_ date: Date) -> String {
        receivedDates.append(date)
        return formattedDate
    }

    func stringToDate(_: String) -> Date? {
        nil
    }
}

private final class LogRotatorSpy: LogRotating {
    struct Invocation {
        let category: LogCategory
        let maxLogs: Int
    }

    private(set) var invocations: [Invocation] = []

    func clenupOutdatedLogs(logCategory: LogCategory, maxLogs: Int) throws {
        invocations.append(Invocation(category: logCategory, maxLogs: maxLogs))
    }
}
