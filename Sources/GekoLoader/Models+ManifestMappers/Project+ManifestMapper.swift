import Foundation
import GekoGraph
import ProjectDescription

extension Project {
    /// Maps a `ProjectDescription.Project` instance into a `GekoGraph.Project` instance.
    /// Glob patterns in file elements are unfolded as part of the mapping.
    /// - Parameters:
    ///   - generatorPaths: Generator paths.
    public mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        try settings.resolvePaths(generatorPaths: generatorPaths)

        for i in 0 ..< targets.count {
            try targets[i].resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< schemes.count {
            try schemes[i].resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< additionalFiles.count {
            try additionalFiles[i].resolvePaths(generatorPaths: generatorPaths)
        }

        try fileHeaderTemplate?.resolvePaths(generatorPaths: generatorPaths)
    }

    public mutating func resolveExternalDependencies(externalDependencies: [String: [TargetDependency]]) throws {
        for i in 0 ..< targets.count {
            try targets[i].resolveExternalDependencies(externalDependencies: externalDependencies)
        }
    }

    public mutating func resolveGlobs(checkFilesExist: Bool) throws  {
        for i in 0 ..< self.targets.count {
            try self.targets[i].resolveGlobs(
                isExternal: isExternal,
                projectType: projectType,
                checkFilesExist: checkFilesExist
            )
        }

        let oldAdditionalFiles = self.additionalFiles
        self.additionalFiles.removeAll(keepingCapacity: true)
        for i in 0 ..< oldAdditionalFiles.count {
            try oldAdditionalFiles[i].resolveGlobs(into: &self.additionalFiles, isExternal: isExternal, checkFilesExist: checkFilesExist)
        }
    }

    public mutating func applyFixits() throws {
        for i in 0 ..< self.targets.count {
            try self.targets[i].applyFixits()
        }
    }
}
