import GekoCacheTesting
import GekoSupport
import GekoGraph
import ProjectDescription
import XCTest
@testable import GekoCache
@testable import GekoCoreTesting
@testable import GekoSupportTesting
@testable import GekoGraphTesting

final class AdditionalCacheStringsHasherTests: GekoUnitTestCase {
    private var subject: AdditionalCacheStringsHasher!
    private var mockContentHashing: MockContentHasher!
    private var systeming: MockSystem!

    override func setUp() {
        super.setUp()
        mockContentHashing = MockContentHasher()
        systeming = MockSystem()
        subject = AdditionalCacheStringsHasher(contentHasher: mockContentHashing, system: systeming)
    }

    override func tearDown() {
        subject = nil
        mockContentHashing = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test() throws {
        // Given
        let profile = ProjectDescription.Cache.Profile.test(name: "Test")
        mockContentHashing.hashStringsSpy = []
        systeming.swiftlangVersionStub = { "6.0.0" }
        let expectedHash = "Test;Debug;;true,false,false;framework;simulator;6.0.0;1.3.0"

        // When
        let hash = try subject.contentHash(
            cacheProfile: profile,
            cacheUserVersion: nil,
            cacheOutputType: .framework,
            destination: .simulator
        )

        XCTAssertEqual(expectedHash, hash)
        XCTAssertEqual(mockContentHashing.hashStringsCallCount, 2)
    }
}
