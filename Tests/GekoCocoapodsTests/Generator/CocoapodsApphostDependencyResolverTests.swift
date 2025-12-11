import Foundation
import GekoSupportTesting
import XCTest
@testable import GekoCocoapods

final class CocoapodsApphostDependencyResolverTests: GekoUnitTestCase {
    func testResolveAppHostDependency() throws {
        let resolver = CocoapodsApphostDependencyResolver(localPodspecNameToPath: ["UnitTestCommon": "/Test/LocalPods/UnitTestCommon"], externalDependencies: ["SMEMBUnitTests": [.project(target: "SMEMBUnitTests-AppHost", path: "/Test/Cache/SMEMBUnitTests")]])

        XCTAssertEqual(try resolver.resolve(appHostName: "UnitTestCommon/AppHost"), .project(target: "UnitTestCommon-AppHost", path: "/Test/LocalPods/UnitTestCommon"))
        XCTAssertEqual(try resolver.resolve(appHostName: "SMEMBUnitTests/AppHost"), .project(target: "SMEMBUnitTests-AppHost", path: "/Test/Cache/SMEMBUnitTests"))
        XCTAssertEqual(try resolver.resolve(appHostName: "NotFound/AppHost"), .target(name: "NotFound-AppHost"))
    }
}
