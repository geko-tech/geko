import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport
import XCTest
@testable import GekoSupportTesting

final class CocoapodsPodspecConverterTests: GekoUnitTestCase {

    private var systemMock: MockSystem!
    private var converter: CocoapodsPodspecConverter!

    override func setUp() {
        super.setUp()

        systemMock = MockSystem()
        converter = CocoapodsPodspecConverter(system: systemMock)
    }

    override func tearDown() {
        systemMock = nil
        converter = nil

        super.tearDown()
    }

    // MARK: - Tests

    func testHappyPath() throws {
        // arrange
        let pathsStub = try createFiles(["Podspec1.podspec", "Podspec2.podspec", "Podspec3.podspec"])
        let stdoutStub = (["Version 1.16.1"] + Array(repeating: podspecContentJSONStub, count: 3)).joined(separator: "\n")
        let commandStub = "some_command"
        systemMock.stubs["\(commandStub) ipc repl"] = (stderror: nil, stdout: stdoutStub, exitstatus: 0)

        var commandInput: String?
        systemMock.withInputStub = { input in
            commandInput = input
        }

        // act
        let result = try converter.convert(paths: pathsStub.map { $0.pathString }, shellCommand: [commandStub])

        // assert
        XCTAssertEqual(pathsStub.map { "spec \($0.pathString)" }.joined(separator: "\n"), commandInput)
        XCTAssertEqual(pathsStub[0].pathString, result[0].podspecPath)
        XCTAssertEqual(try XCTUnwrap(podspecContentJSONStub.data(using: .utf8)), result[0].podspecData)
        XCTAssertEqual(pathsStub[1].pathString, result[1].podspecPath)
        XCTAssertEqual(try XCTUnwrap(podspecContentJSONStub.data(using: .utf8)), result[1].podspecData)
        XCTAssertEqual(pathsStub[2].pathString, result[2].podspecPath)
        XCTAssertEqual(try XCTUnwrap(podspecContentJSONStub.data(using: .utf8)), result[2].podspecData)
    }

    func testSystemCaptureError() throws {
        // arrange
        let pathsStub = try createFiles(["Podspec1.podspec", "Podspec2.podspec", "Podspec3.podspec"])
        let commandStub = "some_command"
        let stderrStub = "mock error"
        let stdoutStub = "some log"
        let codeStub = 1
        systemMock.stubs["some_command ipc repl"] = (stderror: stderrStub, stdout: stdoutStub, exitstatus: 1)

        // act
        // assert
        XCTAssertThrowsSpecific(
            try converter.convert(paths: pathsStub.map { $0.pathString }, shellCommand: [commandStub]),
            GekoSupport.SystemError.terminated(
                command: "some_command",
                code: Int32(codeStub),
                standardError: try XCTUnwrap(stderrStub.data(using: .utf8)),
                standardOutput: try XCTUnwrap(stdoutStub.data(using: .utf8))
            )
        )
    }

    func testErrorLessJsonsThanPodspecs() throws {
        // arrange
        let incorrectSpec = """
        { "name": "MyModule", "source_files" = "MyModule/Classes/**/*"
        """
        let pathsStub = try createFiles(["Podspec1.podspec", "Podspec2.podspec", "Podspec3.podspec"])
        let stdoutStub = (["Version 1.16.1"] + Array(repeating: podspecContentJSONStub, count: 2) + [incorrectSpec]).joined(separator: "\n")
        let commandStub = "some_command"
        systemMock.stubs["\(commandStub) ipc repl"] = (stderror: nil, stdout: stdoutStub, exitstatus: 0)

        // act
        // assert
        XCTAssertThrowsSpecific(
            try converter.convert(paths: pathsStub.map { $0.pathString }, shellCommand: [commandStub]),
            CocoapodsPodspecConverterError.lessJsonsThanPodspecs(specPath: pathsStub[2].pathString, json: "")
        )
    }

    func testErrorMoreJsonsThanPodspecs() throws {
        // arrange
        let pathsStub = try createFiles(["Podspec1.podspec", "Podspec2.podspec", "Podspec3.podspec"])
        let stdoutStub = (["Version 1.16.1"] + Array(repeating: podspecContentJSONStub, count: 4)).joined(separator: "\n")
        let commandStub = "some_command"
        systemMock.stubs["\(commandStub) ipc repl"] = (stderror: nil, stdout: stdoutStub, exitstatus: 0)

        // act
        // assert
        XCTAssertThrowsSpecific(
            try converter.convert(paths: pathsStub.map { $0.pathString }, shellCommand: [commandStub]),
            CocoapodsPodspecConverterError.moreJsonsThanPodspecs
        )
    }

    // MARK: - Private

    private let podspecContentJSONStub = """
    { "name": "MyModule", "source_files" = "MyModule/Classes/**/*" }
    """
}
