import Foundation
import GekoGraph
import ProjectDescription

extension ExecutionAction {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try self.target?.resolvePaths(generatorPaths: generatorPaths)
    }
}

extension TargetReference {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        self.projectPath = try generatorPaths.resolveSchemeActionProjectPath(projectPath)
    }
}
