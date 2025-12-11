import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoCoreTesting
import GekoGraph
import XCTest
import GekoSupport

@testable import GekoCache
@testable import GekoSupportTesting

final class SwiftInterfaceMetadataProviderTests: GekoUnitTestCase {
    private var subject: SwiftInterfaceMetadataProvider!
    
    override func setUp() {
        super.setUp()
        subject = SwiftInterfaceMetadataProvider()
    }
    
    override func tearDown() {
        subject = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func test_swiftinterfaceParse_expectedResult() throws {
        // Given
        let tempDir = try temporaryPath()
        let swiftinterfacePath = tempDir.appending(component: "arm64-apple-ios-simulator.swiftinterface")
        try FileHandler.shared.touch(swiftinterfacePath)
        try FileHandler.shared.write(
            swiftinterfaceContent(),
            path: swiftinterfacePath,
            atomically: true
        )
        
        let expectedFileName = "arm64-apple-ios-simulator"
        let expectedFlags = [
            "-target",
            "arm64-apple-ios15.0-simulator",
            "-enable-objc-interop",
            "-enable-library-evolution",
            "-swift-version",
            "5",
            "-enforce-exclusivity=checked",
            "-Osize",
            "-module-name",
            "AcademyKit",
        ]
        let expectedIgnorableFlags = [
            "-enable-bare-slash-regex",
            "-enable-upcoming-feature",
            "ConciseMagicFile",
        ]
        
        // When
        let metadata = try subject.loadMetadata(at: swiftinterfacePath)
        
        // Then
        XCTAssertEqual(swiftinterfacePath, metadata.path)
        XCTAssertEqual(expectedFlags.sorted(), metadata.flags.sorted())
        XCTAssertEqual(expectedIgnorableFlags.sorted(), metadata.ignorableFlags.sorted())
        XCTAssertEqual(expectedFileName, metadata.fileName)
    }
    
    // MARK: - Helpers
    
    private func swiftinterfaceContent() -> String {
        return """
    // swift-interface-format-version: 1.0
    // swift-compiler-version: Apple Swift version 5.9.2 (swiftlang-5.9.2.2.56 clang-1500.1.0.2.5)
    // swift-module-flags: -target arm64-apple-ios15.0-simulator -enable-objc-interop -enable-library-evolution -swift-version 5 -enforce-exclusivity=checked -Osize -module-name AcademyKit
    // swift-module-flags-ignorable: -enable-upcoming-feature ConciseMagicFile -enable-bare-slash-regex
    import AVFoundation
    @_exported import AcademyKit
    import Combine
    """
    }
}
