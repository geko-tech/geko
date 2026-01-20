#if os(macOS)

import Foundation
import GekoCore
import GekoGraph
import GekoLoader
import ProjectDescription
import XcodeProj
import XCTest
@testable import GekoCoreTesting
@testable import GekoKit
@testable import GekoLoaderTesting
@testable import GekoSupportTesting

private typealias GeneratorParameters = (
    sources: Set<String>,
    cacheOutputType: CacheOutputType,
    cacheProfile: ProjectDescription.Cache.Profile,
    ignoreCache: Bool
)

final class GenerateServiceTests: GekoUnitTestCase {
    var subject: GenerateService!
    var opener: MockOpener!
    var generator: MockGenerator!
    var generatorFactory: MockGeneratorFactory!
    var clock: StubClock!

    override func setUp() {
        super.setUp()
        opener = MockOpener()
        generator = MockGenerator()
        generatorFactory = MockGeneratorFactory()
        generatorFactory.stubbedDefaultResult = generator
        generatorFactory.stubbedFocusResult = generator
        clock = StubClock()
        subject = GenerateService(clock: clock, opener: opener, generatorFactory: generatorFactory)
    }

    override func tearDown() {
        opener = nil
        generator = nil
        subject = nil
        generatorFactory = nil
        clock = nil
        super.tearDown()
    }

    func test_run_fatalErrors_when_theworkspaceGenerationFails() async throws {
        let expectedError = NSError.test()
        generator.generateStub = { _ in
            throw expectedError
        }

        do {
            try await subject
                .run(
                    path: nil,
                    noOpen: true,
                    sources: [],
                    scheme: nil,
                    focusTests: false)
            XCTFail("Must throw")
        } catch {
            XCTAssertEqual(error as NSError?, expectedError)
        }
    }

    func test_run() async throws {
        let workspacePath = try AbsolutePath(validating: "/test.xcworkspace")

        generator.generateStub = { _ in
            workspacePath
        }

        try await subject.run(
            path: nil,
            noOpen: false,
            sources: [],
            scheme: nil,
            focusTests: false
        )

        XCTAssertEqual(opener.openArgs.last?.0, workspacePath.pathString)
    }

    func test_run_timeIsPrinted() async throws {
        // Given
        let workspacePath = try AbsolutePath(validating: "/test.xcworkspace")

        generator.generateStub = { _ in
            workspacePath
        }
        clock.assertOnUnexpectedCalls = true
        clock.primedTimers = [
            0.234,
        ]

        // When
        try await subject.run(
            path: nil,
            noOpen: false,
            sources: [],
            scheme: nil,
            focusTests: false
        )

        // Then
        XCTAssertPrinterOutputContains("Total time taken: 0.234s")
    }

    func test_run_focus_generator() async throws {
        // Given
        let workspacePath = try AbsolutePath(validating: "/test.xcworkspace")

        generator.generateStub = { _ in
            workspacePath
        }

        // When
        try await subject.run(
            path: nil,
            noOpen: false,
            sources: ["test"],
            scheme: nil,
            focusTests: false
        )

        // Then
        XCTAssertTrue(generatorFactory.invokedFocus)
    }

    func test_run_default_generator() async throws {
        // Given
        let workspacePath = try AbsolutePath(validating: "/test.xcworkspace")

        generator.generateStub = { _ in
            workspacePath
        }

        // When
        try await subject.run(
            path: nil,
            noOpen: false,
            sources: [],
            scheme: nil,
            focusTests: false
        )

        // Then
        XCTAssertTrue(generatorFactory.invokedDefault)
    }
}

#endif
