import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoCoreTesting
import GekoGraph
import XCTest
import GekoSupport

@testable import GekoCache
@testable import GekoSupportTesting

final class SwiftModuleMetadataProviderTests: GekoUnitTestCase {
    private var subject: SwiftModuleMetadataProvider!
    
    override func setUp() {
        super.setUp()
        subject = SwiftModuleMetadataProvider()
    }
    
    override func tearDown() {
        subject = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func test_swiftmoduleParse_expectedResult() throws {
        // Given
        let inputAndExpectedData = inputAndExpectedData()
        
        // When/Then
        for (path, expected) in inputAndExpectedData {
            let result = try subject.loadMetadata(at: path)
            XCTAssertEqual(expected, result)
        }
    }
    
    // MARK: - Helpers
    
    private func inputAndExpectedData() -> [AbsolutePath: SwiftModuleMetadata] {
        let arm64iOSSimulator = SwiftModuleMetadata(
            fileName: "arm64-apple-ios-simulator.swiftmodule",
            arch: .arm64,
            platform: .ios,
            platformVariant: .simulator
        )
        let arm64iOS = SwiftModuleMetadata(
            fileName: "arm64-apple-ios.swiftmodule",
            arch: .arm64,
            platform: .ios,
            platformVariant: nil
        )
        let arm64iOSMacabi = SwiftModuleMetadata(
            fileName: "arm64-apple-ios-macabi.swiftmodule",
            arch: .arm64,
            platform: .ios,
            platformVariant: .maccatalyst
        )
        let arm64macos = SwiftModuleMetadata(
            fileName: "arm64-apple-macos.swiftmodule",
            arch: .arm64,
            platform: .macos,
            platformVariant: nil
        )
        let arm64tvos = SwiftModuleMetadata(
            fileName: "arm64-apple-tvos.swiftmodule",
            arch: .arm64,
            platform: .tvos,
            platformVariant: nil
        )
        let arm64tvosSimulator = SwiftModuleMetadata(
            fileName: "arm64-apple-tvos-simulator.swiftmodule",
            arch: .arm64,
            platform: .tvos,
            platformVariant: .simulator
        )
        let x8664tvosSimulator = SwiftModuleMetadata(
            fileName: "x86_64-apple-tvos-simulator.swiftmodule",
            arch: .x8664,
            platform: .tvos,
            platformVariant: .simulator
        )
        let arm6432Watchos = SwiftModuleMetadata(
            fileName: "arm64_32-apple-watchos.swiftmodule",
            arch: .arm6432,
            platform: .watchos,
            platformVariant: nil
        )
        let arm64Watchos = SwiftModuleMetadata(
            fileName: "arm64-apple-watchos.swiftmodule",
            arch: .arm64,
            platform: .watchos,
            platformVariant: nil
        )
        let arm64WatchosSimulator = SwiftModuleMetadata(
            fileName: "arm64-apple-watchos-simulator.swiftmodule",
            arch: .arm64,
            platform: .watchos,
            platformVariant: .simulator
        )
        let x8664WatchosSimulator = SwiftModuleMetadata(
            fileName: "x86_64-apple-watchos-simulator.swiftmodule",
            arch: .x8664,
            platform: .watchos,
            platformVariant: .simulator
        )
        
        return [
            AbsolutePath(stringLiteral: "/arm64-apple-ios-simulator.swiftmodule"): arm64iOSSimulator,
            AbsolutePath(stringLiteral: "/arm64-apple-ios.swiftmodule"): arm64iOS,
            AbsolutePath(stringLiteral: "/arm64-apple-ios-macabi.swiftmodule"): arm64iOSMacabi,
            AbsolutePath(stringLiteral: "/arm64-apple-macos.swiftmodule"): arm64macos,
            AbsolutePath(stringLiteral: "/arm64-apple-tvos.swiftmodule"): arm64tvos,
            AbsolutePath(stringLiteral: "/arm64-apple-tvos-simulator.swiftmodule"): arm64tvosSimulator,
            AbsolutePath(stringLiteral: "/x86_64-apple-tvos-simulator.swiftmodule"): x8664tvosSimulator,
            AbsolutePath(stringLiteral: "/arm64_32-apple-watchos.swiftmodule"): arm6432Watchos,
            AbsolutePath(stringLiteral: "/arm64-apple-watchos.swiftmodule"): arm64Watchos,
            AbsolutePath(stringLiteral: "/arm64-apple-watchos-simulator.swiftmodule"): arm64WatchosSimulator,
            AbsolutePath(stringLiteral: "/x86_64-apple-watchos-simulator.swiftmodule"): x8664WatchosSimulator
        ]
    }
}
