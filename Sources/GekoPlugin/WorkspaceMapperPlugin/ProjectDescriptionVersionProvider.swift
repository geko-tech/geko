import Foundation
import GekoSupport

public protocol ProjectDescriptionVersionProviding {
    var projectDescriptionVersion: String { get }
    /// Needed for acceptance tests, do not use in production
    func override(projectDescriptionVersion: String)
}

public final class ProjectDescriptionVersionProvider: ProjectDescriptionVersionProviding {

    public static var shared: ProjectDescriptionVersionProviding = ProjectDescriptionVersionProvider()
    public var projectDescriptionVersion: String

    public init(projectDescriptionVersion: String = Constants.projectDescriptionVersion) {
        self.projectDescriptionVersion = projectDescriptionVersion
    }

    public func override(projectDescriptionVersion: String) {
        self.projectDescriptionVersion = projectDescriptionVersion
    }
}
