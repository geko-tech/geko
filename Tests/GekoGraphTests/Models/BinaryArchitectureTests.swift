import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest

@testable import GekoSupportTesting

final class BinaryArchitectureTests: GekoTestCase {
    func test_rawValue() {
        XCTAssertEqual(BinaryArchitecture.x8664.rawValue, "x86_64")
        XCTAssertEqual(BinaryArchitecture.i386.rawValue, "i386")
        XCTAssertEqual(BinaryArchitecture.armv7.rawValue, "armv7")
        XCTAssertEqual(BinaryArchitecture.armv7s.rawValue, "armv7s")
        XCTAssertEqual(BinaryArchitecture.arm64.rawValue, "arm64")
        XCTAssertEqual(BinaryArchitecture.armv7k.rawValue, "armv7k")
        XCTAssertEqual(BinaryArchitecture.arm6432.rawValue, "arm64_32")
    }
}
