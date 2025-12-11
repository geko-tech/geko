import Foundation
import ProjectDescription
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoGraph
import GekoSupport

extension GekoGraph.PackageSettings {
    /// Creates `GekoGraph.PackageSettings` instance from `ProjectDescription.PackageSettings`
    /// instance.
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try self.baseSettings.resolvePaths(generatorPaths: generatorPaths)
    }
}
