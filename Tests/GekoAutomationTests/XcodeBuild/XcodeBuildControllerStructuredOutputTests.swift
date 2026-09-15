import Foundation
import GekoCore
import GekoSupport
import ProjectDescription
import XcbeautifyLib
import XCTest

@testable import GekoAutomation
@testable import GekoSupportTesting

final class XcodeBuildControllerStructuredOutputTests: GekoUnitTestCase {
    private var subject: XcodeBuildController!

    override func setUp() {
        super.setUp()
        _ = CommandOutputStore.shared.drain()
        subject = XcodeBuildController(
            formatter: StructuredOutputNoopFormatter(),
            environment: environment,
            logFileStoreHandler: StructuredOutputLogStore(path: FileHandler.shared.currentPath),
            outputParser: XcodeBuildOutputParser(),
            isStructuredOutputEnabled: true
        )
    }

    override func tearDown() {
        subject = nil
        _ = CommandOutputStore.shared.drain()
        super.tearDown()
    }

    func testRetainsStructuredInvocationWhenXcodebuildFails() throws {
        let workspace = try temporaryPath().appending(component: "App.xcworkspace")
        let command = buildCommand(workspace: workspace, scheme: "MainApp")
        system.errorCommand(command, error: try fixture("swift-error"))

        XCTAssertThrowsError(
            try subject.build(
                .workspace(workspace),
                scheme: "MainApp",
                destination: nil,
                rosetta: false,
                derivedDataPath: nil,
                arguments: [],
                passthroughXcodeBuildArguments: [],
                eventHandler: nil
            )
        ) { error in
            XCTAssertTrue(error is XcodeBuildError)
        }

        let invocations = try storedInvocations()
        XCTAssertEqual(invocations.count, 1)
        XCTAssertEqual(invocations.first?["status"] as? String, "failed")
        XCTAssertEqual(invocations.first?["scheme"] as? String, "MainApp")
        XCTAssertEqual((invocations.first?["errors"] as? [Any])?.count, 1)
    }

    func testAccumulatesMultipleXcodebuildInvocations() throws {
        let workspace = try temporaryPath().appending(component: "App.xcworkspace")
        for scheme in ["First", "Second"] {
            system.succeedCommand(buildCommand(workspace: workspace, scheme: scheme), output: try fixture("success"))
            try subject.build(
                .workspace(workspace),
                scheme: scheme,
                destination: nil,
                rosetta: false,
                derivedDataPath: nil,
                arguments: [],
                passthroughXcodeBuildArguments: [],
                eventHandler: nil
            )
        }

        let invocations = try storedInvocations()
        XCTAssertEqual(invocations.compactMap { $0["scheme"] as? String }, ["First", "Second"])
        XCTAssertNil(invocations.first?["errors"])
        XCTAssertNil(invocations.first?["warnings"])
        XCTAssertNil(invocations.first?["linkerErrors"])
        XCTAssertNil(invocations.first?["testFailures"])
    }

    func testKeepsWarningCountButOmitsWarningDetailsByDefault() throws {
        let workspace = try temporaryPath().appending(component: "App.xcworkspace")
        system.succeedCommand(
            buildCommand(workspace: workspace, scheme: "MainApp"),
            output: try fixture("warning")
        )

        try subject.build(
            .workspace(workspace),
            scheme: "MainApp",
            destination: nil,
            rosetta: false,
            derivedDataPath: nil,
            arguments: [],
            passthroughXcodeBuildArguments: [],
            eventHandler: nil
        )

        let invocation = try XCTUnwrap(storedInvocations().first)
        XCTAssertEqual(invocation["warningCount"] as? Int, 1)
        XCTAssertNil(invocation["warnings"])
    }

    func testIncludesWarningDetailsWhenEnabled() throws {
        let workspace = try temporaryPath().appending(component: "App.xcworkspace")
        let command = buildCommand(workspace: workspace, scheme: "MainApp")
        system.succeedCommand(command, output: try fixture("warning"))
        subject = XcodeBuildController(
            formatter: StructuredOutputNoopFormatter(),
            environment: environment,
            logFileStoreHandler: StructuredOutputLogStore(path: FileHandler.shared.currentPath),
            outputParser: XcodeBuildOutputParser(),
            isStructuredOutputEnabled: true,
            includeStructuredBuildWarnings: true
        )

        try subject.build(
            .workspace(workspace),
            scheme: "MainApp",
            destination: nil,
            rosetta: false,
            derivedDataPath: nil,
            arguments: [],
            passthroughXcodeBuildArguments: [],
            eventHandler: nil
        )

        let invocation = try XCTUnwrap(storedInvocations().first)
        XCTAssertEqual(invocation["warningCount"] as? Int, 1)
        XCTAssertEqual((invocation["warnings"] as? [Any])?.count, 1)
    }

    private func buildCommand(workspace: AbsolutePath, scheme: String) -> [String] {
        ["/usr/bin/xcrun", "xcodebuild", "build", "-scheme", scheme] +
            XcodeBuildTarget.workspace(workspace).xcodebuildArguments
    }

    private func fixture(_ name: String) throws -> String {
        let path = fixturePath(
            path: try RelativePath(validating: "XcodeBuild/\(name).log")
        )
        return try String(contentsOf: path.asURL, encoding: .utf8)
    }

    private func storedInvocations() throws -> [[String: Any]] {
        let snapshot = CommandOutputStore.shared.drain()
        let data = try JSONOutputRenderer.encode(
            CommandOutput(exitCode: 0, errors: [], warnings: [], data: snapshot.data)
        )
        let response = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let commandData = try XCTUnwrap(response["data"] as? [String: Any])
        let xcodebuild = try XCTUnwrap(commandData["xcodebuild"] as? [String: Any])
        return try XCTUnwrap(xcodebuild["invocations"] as? [[String: Any]])
    }
}

private struct StructuredOutputNoopFormatter: Formatting {
    func format(
        line _: String,
        output _: @escaping (String, XcbeautifyLib.OutputType) throws -> Void
    ) throws {}

    func format(_ line: String) -> String? {
        line
    }
}

private final class StructuredOutputLogStore: LogFileStoreHandling {
    private let path: AbsolutePath

    init(path: AbsolutePath) {
        self.path = path
    }

    func createPath(logFile: LogFile, date _: Date) throws -> AbsolutePath {
        path.appending(component: logFile.rawValue)
    }

    func write(_: String, logFile _: LogFile) throws {}
    func close(logFile _: LogFile) throws {}
}
