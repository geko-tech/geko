import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension Workspace {
    /// Maps a ProjectDescription.Workspace instance into a GekoGraph.Workspace model.
    /// - Parameters:
    ///   - generatorPaths: Generator paths.
    public mutating func resolvePaths(
        generatorPaths: GeneratorPaths
    ) throws {
        for i in 0 ..< self.additionalFiles.count {
            try self.additionalFiles[i].resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< schemes.count {
            try schemes[i].resolvePaths(generatorPaths: generatorPaths)
        }

        try generationOptions.resolvePaths(generatorPaths: generatorPaths)

        try fileHeaderTemplate?.resolvePaths(generatorPaths: generatorPaths)

        for i in 0 ..< self.projects.count {
            self.projects[i] = try generatorPaths.resolve(path: self.projects[i])
        }
    }

    public mutating func resolveGlobs(manifestLoader: ManifestLoading) throws {
        var resolvedProjects: [AbsolutePath] = []

        let oldAdditionalFiles = self.additionalFiles
        self.additionalFiles.removeAll(keepingCapacity: true)
        for i in 0 ..< oldAdditionalFiles.count {
            try oldAdditionalFiles[i].resolveGlobs(into: &self.additionalFiles, isExternal: false, checkFilesExist: true)
        }

        for i in 0 ..< self.projects.count {
            let projects = try FileHandler.shared.glob([self.projects[i]], excluding: [], errorLevel: .none, checkFilesExist: true)
                .lazy
                .filter {
                    guard FileHandler.shared.isFolder($0) else { return false }

                    return manifestLoader.manifests(at: $0).contains(.project)
                }

            if projects.isEmpty {
                // FIXME: This should be done in a linter.
                // Before we can do that we have to change the linters to run with the GekoCore models and not the
                // ProjectDescription ones.
                logger.warning("No projects found at: \(self.projects[i])")
            }

            resolvedProjects.append(contentsOf: projects)
        }

        self.projects = resolvedProjects

        try generationOptions.resolveGlobs()
    }
}
