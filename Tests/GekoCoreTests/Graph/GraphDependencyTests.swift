import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGraph
import XCTest
@testable import GekoCore
@testable import GekoSupportTesting

final class GraphDependencyTests: GekoUnitTestCase {
    func test_isTarget() {
        XCTAssertFalse(GraphDependency.testXCFramework().isTarget)
        XCTAssertFalse(GraphDependency.testFramework().isTarget)
        XCTAssertFalse(GraphDependency.testLibrary().isTarget)
        XCTAssertTrue(GraphDependency.testTarget().isTarget)
        XCTAssertFalse(GraphDependency.testSDK().isTarget)
    }

    func test_isPrecompiled() {
        XCTAssertTrue(GraphDependency.testXCFramework().isPrecompiled)
        XCTAssertTrue(GraphDependency.testFramework().isPrecompiled)
        XCTAssertTrue(GraphDependency.testLibrary().isPrecompiled)
        XCTAssertFalse(GraphDependency.testTarget().isPrecompiled)
        XCTAssertFalse(GraphDependency.testSDK().isPrecompiled)
    }

    func test_isStaticPrecompiled() {
        XCTAssertTrue(GraphDependency.testXCFramework(linking: .static).isStaticPrecompiled)
        XCTAssertTrue(GraphDependency.testFramework(linking: .static).isStaticPrecompiled)
        XCTAssertTrue(GraphDependency.testLibrary(linking: .static).isStaticPrecompiled)
        XCTAssertFalse(GraphDependency.testTarget().isStaticPrecompiled)
        XCTAssertFalse(GraphDependency.testSDK().isStaticPrecompiled)
    }

    func test_isDynamicPrecompiled() {
        XCTAssertTrue(GraphDependency.testXCFramework(linking: .dynamic).isDynamicPrecompiled)
        XCTAssertTrue(GraphDependency.testFramework(linking: .dynamic).isDynamicPrecompiled)
        XCTAssertTrue(GraphDependency.testLibrary(linking: .dynamic).isDynamicPrecompiled)
        XCTAssertFalse(GraphDependency.testTarget().isDynamicPrecompiled)
        XCTAssertFalse(GraphDependency.testSDK().isDynamicPrecompiled)
    }
}
