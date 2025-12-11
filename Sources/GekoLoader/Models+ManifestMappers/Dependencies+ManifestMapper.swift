import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport

import struct ProjectDescription.AbsolutePath

extension GekoGraph.Dependencies {
    /// Maps a ProjectDescription.Dependencies instance into a GekoGraph.Dependencies instance.
    /// - Parameters:
    ///   - generatorPaths: Generator paths.
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try self.cocoapods?.resolvePaths(generatorPaths: generatorPaths)
    }
}
