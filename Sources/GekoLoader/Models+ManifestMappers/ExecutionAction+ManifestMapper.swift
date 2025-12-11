import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoGraph

extension GekoGraph.ExecutionAction {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try self.target?.resolvePaths(generatorPaths: generatorPaths)
    }
}

extension GekoGraph.TargetReference {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        self.projectPath = try generatorPaths.resolveSchemeActionProjectPath(projectPath)
    }
}
