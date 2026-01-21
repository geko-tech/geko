import Foundation
import GekoCacheTesting
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest
@testable import GekoCache
@testable import GekoSupportTesting

final class CacheProfileContentHasherTests: GekoUnitTestCase {
    private var subject: CacheProfileContentHasher!
    private var mockContentHasher: MockContentHasher!

    override func setUp() {
        super.setUp()
        mockContentHasher = MockContentHasher()
        subject = CacheProfileContentHasher(contentHasher: mockContentHasher)
    }

    override func tearDown() {
        subject = nil
        mockContentHasher = nil
        super.tearDown()
    }

    func test_hash_callsContentHasherWithExpectedStrings() throws {
        // When
        let cacheProfile = ProjectDescription.Cache.Profile(
            name: "Development",
            configuration: "Debug",
            platforms: [.iOS: .options(arch: .arm64, os: "15.0.0", device: "iPhone 12")]
        )

        // Then
        let hash = try subject.hash(cacheProfile: cacheProfile)

        XCTAssertEqual(hash, "Development;Debug;iOS:Arch: arm64,os: 15.0.0,device: iPhone 12;true,false,false")
        XCTAssertEqual(mockContentHasher.hashStringsCallCount, 1)
    }

    func test_hash_withDefaultOptions() throws {
        // When
        let cacheProfile = ProjectDescription.Cache.Profile(
            name: "Development",
            configuration: "Debug",
            platforms: [.iOS: .options(arch: .arm64, os: "15.0.0", device: "iPhone 12")],
            options: .options()
        )

        // Then
        let hash = try subject.hash(cacheProfile: cacheProfile)
        XCTAssertEqual(hash, "Development;Debug;iOS:Arch: arm64,os: 15.0.0,device: iPhone 12;true,false,false")
        XCTAssertEqual(mockContentHasher.hashStringsCallCount, 1)
    }

    func test_hash_withActiveResourcesOption() throws {
        // When
        let cacheProfile = ProjectDescription.Cache.Profile(
            name: "Development",
            configuration: "Debug",
            platforms: [.iOS: .options(arch: .arm64, os: "15.0.0", device: "iPhone 12")],
            options: .options(
                onlyActiveResourcesInBundles: false
            )
        )

        // Then
        let hash = try subject.hash(cacheProfile: cacheProfile)
        XCTAssertEqual(hash, "Development;Debug;iOS:Arch: arm64,os: 15.0.0,device: iPhone 12;false,false,false")
        XCTAssertEqual(mockContentHasher.hashStringsCallCount, 1)
    }

    func test_hash_withExportCoverageProfiles() throws {
        // When
        let cacheProfile = ProjectDescription.Cache.Profile(
            name: "Development",
            configuration: "Debug",
            platforms: [.iOS: .options(arch: .arm64, os: "15.0.0", device: "iPhone 12")],
            options: .options(
                exportCoverageProfiles: true
            )
        )

        // Then
        let hash = try subject.hash(cacheProfile: cacheProfile)
        XCTAssertEqual(hash, "Development;Debug;iOS:Arch: arm64,os: 15.0.0,device: iPhone 12;true,true,false")
        XCTAssertEqual(mockContentHasher.hashStringsCallCount, 1)
    }

    func test_hash_withSwiftModuleCacheEnabled() throws {
        // When
        let cacheProfile = ProjectDescription.Cache.Profile(
            name: "Development",
            configuration: "Debug",
            platforms: [.iOS: .options(arch: .arm64, os: "15.0.0", device: "iPhone 12")],
            options: .options(
                swiftModuleCacheEnabled: true
            )
        )

        // Then
        let hash = try subject.hash(cacheProfile: cacheProfile)
        XCTAssertEqual(hash, "Development;Debug;iOS:Arch: arm64,os: 15.0.0,device: iPhone 12;true,false,true")
        XCTAssertEqual(mockContentHasher.hashStringsCallCount, 1)
    }
}
