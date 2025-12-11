import Foundation
import ProjectDescription

public typealias TargetReference = ProjectDescription.TargetReference

extension TargetReference {
    public var name: String {
        self.targetName
    }

    public init(projectPath: AbsolutePath, name: String) {
        self.init(projectPath: projectPath, target: name)
    }
}
