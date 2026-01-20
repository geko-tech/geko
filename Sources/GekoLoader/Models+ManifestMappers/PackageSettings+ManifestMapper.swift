import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension PackageSettings {
    /// Creates `GekoGraph.PackageSettings` instance from `ProjectDescription.PackageSettings`
    /// instance.
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try self.baseSettings.resolvePaths(generatorPaths: generatorPaths)
    }
}
