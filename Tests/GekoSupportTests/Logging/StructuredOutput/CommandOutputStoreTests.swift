import Foundation
import XCTest

@testable import GekoSupport

final class CommandOutputStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = CommandOutputStore.shared.drain()
    }

    override func tearDown() {
        _ = CommandOutputStore.shared.drain()
        super.tearDown()
    }

    func testDrainReturnsOneSnapshotAndClearsAllState() throws {
        CommandOutputStore.shared.appendWarning("warning")
        CommandOutputStore.shared.appendError("error")
        CommandOutputStore.shared.set(.workspacePath, value: "/tmp/App.xcworkspace")
        CommandOutputStore.shared.set(FocusOutputKey.focusedTargets, value: ["App", "AppTests"])

        let snapshot = CommandOutputStore.shared.drain()
        let object = try jsonObject(from: snapshot)

        XCTAssertEqual(snapshot.warnings.map(\.message), ["warning"])
        XCTAssertEqual(snapshot.errors.map(\.message), ["error"])
        XCTAssertEqual(object["workspacePath"] as? String, "/tmp/App.xcworkspace")
        XCTAssertEqual(
            (object["focus"] as? [String: Any])?["focusedTargets"] as? [String],
            ["App", "AppTests"]
        )

        let emptySnapshot = CommandOutputStore.shared.drain()
        XCTAssertTrue(emptySnapshot.warnings.isEmpty)
        XCTAssertTrue(emptySnapshot.errors.isEmpty)
        XCTAssertTrue(emptySnapshot.data.isEmpty)
    }

    func testDrainStartsANewCollection() {
        _ = CommandOutputStore.shared.drain()

        CommandOutputStore.shared.appendWarning("next warning")
        CommandOutputStore.shared.set(.workspacePath, value: "next path")

        let snapshot = CommandOutputStore.shared.drain()
        XCTAssertEqual(snapshot.warnings.map(\.message), ["next warning"])
        XCTAssertFalse(snapshot.data.isEmpty)
    }

    func testConcurrentDiagnosticsAreNotLost() {
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            CommandOutputStore.shared.appendWarning("warning \(index)")
            CommandOutputStore.shared.appendError("error \(index)")
        }

        let snapshot = CommandOutputStore.shared.drain()
        XCTAssertEqual(snapshot.warnings.count, 100)
        XCTAssertEqual(snapshot.errors.count, 100)
    }

    func testAppendAccumulatesValuesWithoutOverwritingPreviousValues() throws {
        CommandOutputStore.shared.append(XcodeBuildOutputKey.invocations, value: ["scheme": "First"])
        CommandOutputStore.shared.append(XcodeBuildOutputKey.invocations, value: ["scheme": "Second"])

        let object = try jsonObject(from: CommandOutputStore.shared.drain())
        let xcodebuild = try XCTUnwrap(object["xcodebuild"] as? [String: Any])
        let invocations = try XCTUnwrap(xcodebuild["invocations"] as? [[String: String]])

        XCTAssertEqual(invocations.map { $0["scheme"] }, ["First", "Second"])
    }

    func testConcurrentAppendsAreNotLost() throws {
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            CommandOutputStore.shared.append(XcodeBuildOutputKey.invocations, value: index)
        }

        let object = try jsonObject(from: CommandOutputStore.shared.drain())
        let xcodebuild = try XCTUnwrap(object["xcodebuild"] as? [String: Any])
        let invocations = try XCTUnwrap(xcodebuild["invocations"] as? [Int])

        XCTAssertEqual(invocations.count, 100)
        XCTAssertEqual(Set(invocations), Set(0 ..< 100))
    }

    func testRendererOmitsEmptyDataAndProducesOneJSONObject() throws {
        let output = CommandOutput(
            exitCode: 0,
            errors: [],
            warnings: [],
            data: nil
        )

        let data = try JSONOutputRenderer.encode(output)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(object["exitCode"] as? Int, 0)
        XCTAssertEqual((object["errors"] as? [Any])?.count, 0)
        XCTAssertEqual((object["warnings"] as? [Any])?.count, 0)
        XCTAssertNil(object["data"])
    }

    private func jsonObject(from snapshot: CommandOutputSnapshot) throws -> [String: Any] {
        let data = try JSONOutputRenderer.encode(
            CommandOutput(
                exitCode: 0,
                errors: snapshot.errors,
                warnings: snapshot.warnings,
                data: snapshot.data
            )
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        return try XCTUnwrap(object["data"] as? [String: Any])
    }
}
