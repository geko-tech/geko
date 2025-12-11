import ArgumentParser
import Foundation
import GekoAnalytics
import GekoSupport
import XCTest

@testable import GekoKit
@testable import GekoSupportTesting

final class CommandEventFactoryTests: GekoUnitTestCase {
    private var subject: CommandEventFactory!
    private var mockMachineEnv: MachineEnvironmentRetrieving!

    override func setUp() {
        super.setUp()
        mockMachineEnv = MockMachineEnvironment()
        subject = CommandEventFactory(machineEnvironment: mockMachineEnv)
    }

    override func tearDown() {
        subject = nil
        mockMachineEnv = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_tagCommand_tagsExpectedCommand() throws {
        // Given
        let info = TrackableCommandInfo(
            name: "cache",
            subcommand: "warm",
            parameters: ["foo": "bar"],
            commandArguments: ["cache", "warm"],
            durationInMs: 5000,
            isError: false
        )
        let expectedEvent = CommandEvent(
            name: "cache",
            subcommand: "warm",
            params: ["foo": "bar"],
            commandArguments: ["cache", "warm"],
            durationInMs: 5000,
            clientId: "123",
            gekoVersion: Constants.version,
            swiftVersion: "5.1",
            os: "macOS",
            osVersion: "10.15.0",
            machineHardwareName: "arm64",
            isCI: false,
            isError: false
        )

        // When
        let event = subject.make(from: info)

        // Then
        XCTAssertEqual(event.name, expectedEvent.name)
        XCTAssertEqual(event.subcommand, expectedEvent.subcommand)
        XCTAssertEqual(event.params, expectedEvent.params)
        XCTAssertEqual(event.durationInMs, expectedEvent.durationInMs)
        XCTAssertEqual(event.clientId, expectedEvent.clientId)
        XCTAssertEqual(event.gekoVersion, expectedEvent.gekoVersion)
        XCTAssertEqual(event.swiftVersion, expectedEvent.swiftVersion)
        XCTAssertEqual(event.os, expectedEvent.os)
        XCTAssertEqual(event.osVersion, expectedEvent.osVersion)
        XCTAssertEqual(event.machineHardwareName, expectedEvent.machineHardwareName)
        XCTAssertEqual(event.isCI, expectedEvent.isCI)
    }
}

private final class MockMachineEnvironment: MachineEnvironmentRetrieving {
    var clientId: String { "123" }
    var os: String { "macOS" }
    var osVersion: String { "10.15.0" }
    var swiftVersion: String { "5.1" }
    var hardwareName: String { "arm64" }
    var isCI: Bool { false }
}
