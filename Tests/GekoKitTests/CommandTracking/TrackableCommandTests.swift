import AnyCodable
import ArgumentParser
import Foundation
import GekoAnalytics
import GekoAnalyticsTesting
import GekoSupport
import XCTest

@testable import GekoKit
@testable import GekoSupportTesting

final class TrackableCommandTests: GekoTestCase {
    private var subject: TrackableCommand!
    private var store: MockGekoAnalyticsStoreHandler!

    override func setUp() {
        super.setUp()
        store = MockGekoAnalyticsStoreHandler()
    }

    override func tearDown() {
        subject = nil
        store = nil
        super.tearDown()
    }

    private func makeSubject(flag: Bool = true) {
        subject = TrackableCommand(
            command: TestCommand(flag: flag),
            commandArguments: ["cache", "warm"],
            clock: WallClock(),
            store: store
        )
    }

    // MARK: - Tests

    func test_whenParamsHaveFlagTrue_storeEventWithExpectedParameters() async throws {
        // Given
        makeSubject(flag: true)
        let expectedParams: [String: AnyCodable] = ["flag": true]

        // When
        try await subject.run()

        // Then
        XCTAssertTrue(store.invokedStoreCommand)
        let event = try XCTUnwrap(store.invokedStoreCommandParameter)
        XCTAssertEqual(event.name, "test")
        XCTAssertEqual(event.params, expectedParams)
    }

    func test_whenParamsHaveFlagFalse_storeEventWithExpectedParameters() async throws {
        // Given
        makeSubject(flag: false)
        let expectedParams: [String: AnyCodable] = ["flag": false]
        // When
        try await subject.run()

        // Then
        XCTAssertTrue(store.invokedStoreCommand)
        let event = try XCTUnwrap(store.invokedStoreCommandParameter)
        XCTAssertEqual(event.name, "test")
        XCTAssertEqual(event.params, expectedParams)
    }
}

private struct TestCommand: ParsableCommand, HasTrackableParameters {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "test")
    }

    var flag: Bool = false

    static var analyticsDelegate: TrackableParametersDelegate?

    func run() throws {
        TestCommand.analyticsDelegate?.addParameters(["flag": AnyCodable(flag)])
    }
}
