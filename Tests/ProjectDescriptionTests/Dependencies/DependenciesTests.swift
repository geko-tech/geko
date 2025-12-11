import Foundation
import XCTest

@testable import ProjectDescription

final class DependenciesTests: XCTestCase {
    func test_dependencies_codable() throws {
        let subject = Dependencies(
            cocoapods: CocoapodsDependencies(
                repos: ["https://cdn.cocoapods.org/"],
                dependencies: [
                    .cdn(name: "test", requirement: .exact("1.0.0"), source: "https://cdn.cocoapods.org/")
                ])
        )
        XCTAssertCodable(subject)
    }
}
