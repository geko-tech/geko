import Foundation
import struct ProjectDescription.AbsolutePath
import GekoGraph
import GekoSupport

// swiftlint:disable:next type_name
public protocol ProjectDescriptionHelpersBuilderFactoring {
    func projectDescriptionHelpersBuilder(cacheDirectory: AbsolutePath) -> ProjectDescriptionHelpersBuilding
}

public final class ProjectDescriptionHelpersBuilderFactory: ProjectDescriptionHelpersBuilderFactoring {
    private let helpersHasher: ProjectDescriptionHelpersHashing

    public init(helpersHasher: ProjectDescriptionHelpersHashing) {
        self.helpersHasher = helpersHasher
    }

    public func projectDescriptionHelpersBuilder(cacheDirectory: AbsolutePath) -> ProjectDescriptionHelpersBuilding {
        ProjectDescriptionHelpersBuilder(
            projectDescriptionHelpersHasher: helpersHasher,
            cacheDirectory: cacheDirectory
        )
    }
}
