import Foundation
import GekoGraph
import ProjectDescription
import XCTest

extension PlatformCondition {
    static func test(_ platformFilters: PlatformFilters) throws -> PlatformCondition {
        try XCTUnwrap(.when(platformFilters))
    }
}
