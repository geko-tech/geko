import Foundation
import GekoCacheTesting
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoSupport
import XCTest
@testable import GekoCache
@testable import GekoSupportTesting

final class SettingsContentHasherTests: GekoUnitTestCase {
    private var subject: SettingsContentHasher!
    private var mockContentHasher: MockContentHasher!
    private let filePath1 = try! AbsolutePath(validating: "/file1")

    override func setUp() {
        super.setUp()
        mockContentHasher = MockContentHasher()
        subject = SettingsContentHasher(contentHasher: mockContentHasher)
    }

    override func tearDown() {
        subject = nil
        mockContentHasher = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_hash_whenRecommended_withXCConfig_callsContentHasherWithExpectedStrings() throws {
        mockContentHasher.stubHashForPath[filePath1] = "xconfigHash"

        // Given
        let settings = Settings(
            base: ["CURRENT_PROJECT_VERSION": SettingValue.string("1")],
            configurations: [
                BuildConfiguration
                    .debug("dev"): Configuration(settings: ["SWIFT_VERSION": SettingValue.string("5")], xcconfig: filePath1),
            ],
            defaultSettings: .recommended
        )

        // When
        let hash = try subject.hash(settings: settings, cacheProfile: .test(name: "Debug", configuration: "dev"))

        // Then
        XCTAssertEqual(
            hash,
            "CURRENT_PROJECT_VERSION:string(\"1\")-hash;dev;debug;SWIFT_VERSION:string(\"5\")-hashxconfigHash;recommended"
        )
    }

    func test_hash_whenEssential_withoutXCConfig_callsContentHasherWithExpectedStrings() throws {
        mockContentHasher.stubHashForPath[filePath1] = "xconfigHash"

        // Given
        let settings = Settings(
            base: ["CURRENT_PROJECT_VERSION": SettingValue.string("2")],
            configurations: [
                BuildConfiguration
                    .release("prod"): Configuration(settings: ["SWIFT_VERSION": SettingValue.string("5")], xcconfig: nil),
            ],
            defaultSettings: .essential
        )

        // When
        let hash = try subject.hash(settings: settings, cacheProfile: .test(name: "Prod", configuration: "prod"))

        // Then
        XCTAssertEqual(hash, "CURRENT_PROJECT_VERSION:string(\"2\")-hash;prod;release;SWIFT_VERSION:string(\"5\")-hash;essential")
    }
    
    func test_hash_whenEssential_withoutXCConfig_callsContentHasherWithExpectedStrings_notMatchCacheProfile() throws {
        mockContentHasher.stubHashForPath[filePath1] = "xconfigHash"

        // Given
        let settings = Settings(
            base: ["CURRENT_PROJECT_VERSION": SettingValue.string("2")],
            configurations: [
                BuildConfiguration
                    .debug("dev"): Configuration(settings: ["SWIFT_VERSION": SettingValue.string("5")], xcconfig: nil),
                BuildConfiguration
                    .release("prod-qa"): Configuration(settings: ["SWIFT_VERSION": SettingValue.string("5")], xcconfig: nil),
            ],
            defaultSettings: .essential
        )

        // When
        let hash = try subject.hash(settings: settings, cacheProfile: .test(name: "Prod", configuration: "prod"))

        // Then
        XCTAssertEqual(hash, "CURRENT_PROJECT_VERSION:string(\"2\")-hash;;essential")
    }
}
