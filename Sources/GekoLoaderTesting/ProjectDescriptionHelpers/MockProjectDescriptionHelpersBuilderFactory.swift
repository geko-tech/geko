import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoSupport

@testable import GekoLoader

// swiftlint:disable:next type_name
public final class MockProjectDescriptionHelpersBuilderFactory: ProjectDescriptionHelpersBuilderFactoring {
    public var projectDescriptionHelpersBuilderStub: ((AbsolutePath) -> ProjectDescriptionHelpersBuilding)!
    public func projectDescriptionHelpersBuilder(cacheDirectory: AbsolutePath) -> ProjectDescriptionHelpersBuilding {
        projectDescriptionHelpersBuilderStub(cacheDirectory)
    }
}
