import Foundation
import ProjectDescription

extension TargetReference {
    public var name: String {
        self.targetName
    }

    public init(projectPath: AbsolutePath, name: String) {
        self.init(projectPath: projectPath, target: name)
    }
}
