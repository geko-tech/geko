import Foundation
import GekoGraph
import ProjectDescription
import XCTest
@testable import GekoCore
@testable import GekoCoreTesting
@testable import GekoSupportTesting

final class GraphTargetTests: GekoUnitTestCase {
    func test_comparable() {
        XCTAssertTrue(GraphTarget.test(target: Target.test(name: "a")) < GraphTarget.test(target: Target.test(name: "b")))
        XCTAssertFalse(GraphTarget.test(target: Target.test(name: "b")) < GraphTarget.test(target: Target.test(name: "a")))
        XCTAssertTrue(
            GraphTarget.test(path: "/a", target: Target.test(name: "a")) < GraphTarget
                .test(path: "/b", target: Target.test(name: "a"))
        )
        XCTAssertFalse(
            GraphTarget.test(path: "/b", target: Target.test(name: "a")) < GraphTarget
                .test(path: "/a", target: Target.test(name: "a"))
        )
    }
}
