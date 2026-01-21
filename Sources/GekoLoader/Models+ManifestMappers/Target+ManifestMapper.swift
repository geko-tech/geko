import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public enum TargetManifestMapperError: FatalError {
    case invalidResourcesGlob(targetName: String, invalidGlobs: [InvalidGlob])

    public var type: ErrorType { .abort }

    public var description: String {
        switch self {
        case let .invalidResourcesGlob(targetName: targetName, invalidGlobs: invalidGlobs):
            return "The target \(targetName) has the following invalid resource globs:\n" + invalidGlobs.invalidGlobsDescription
        }
    }
}

// swiftlint:disable function_body_length
extension Target {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        for i in 0 ..< self.dependencies.count {
            try self.dependencies[i].resolvePaths(generatorPaths: generatorPaths)
        }
        for i in 0 ..< self.ignoreDependencies.count {
            try self.ignoreDependencies[i].resolvePaths(generatorPaths: generatorPaths)
        }
        for i in 0 ..< self.prioritizeDependencies.count {
            try self.prioritizeDependencies[i].resolvePaths(generatorPaths: generatorPaths)
        }

        try infoPlist?.resolvePaths(generatorPaths: generatorPaths)
        try entitlements?.resolvePaths(generatorPaths: generatorPaths)
        try settings?.resolvePaths(generatorPaths: generatorPaths)

        for i in 0 ..< self.buildableFolders.count {
            try self.buildableFolders[i].resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< self.playgrounds.count {
            try self.playgrounds[i] = generatorPaths.resolve(path: self.playgrounds[i])
        }

        for i in 0 ..< self.sources.count {
            try self.sources[i].resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< self.resources.count {
            try self.resources[i].resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< copyFiles.count {
            try copyFiles[i].resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< (headers?.list.count ?? 0) {
            try headers?.list[i].resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< coreDataModels.count {
            try coreDataModels[i].resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< scripts.count {
            try scripts[i].resolvePaths(generatorPaths: generatorPaths)
        }

        for i in 0 ..< self.additionalFiles.count {
            try self.additionalFiles[i].resolvePaths(generatorPaths: generatorPaths)
        }

        self.filesGroup = .group(name: "Project")
    }

    mutating func resolveExternalDependencies(externalDependencies: [String: [TargetDependency]]) throws {
        let oldDependencies = self.dependencies
        self.dependencies.removeAll(keepingCapacity: true)
        for i in 0 ..< oldDependencies.count {
            try oldDependencies[i].resolveDependencies(into: &self.dependencies, externalDependencies: externalDependencies)
        }

        let oldIgnoreDependencies = self.ignoreDependencies
        self.ignoreDependencies.removeAll(keepingCapacity: true)
        for i in 0 ..< oldIgnoreDependencies.count {
            try oldIgnoreDependencies[i].resolveDependencies(into: &self.ignoreDependencies, externalDependencies: externalDependencies)
        }

        let oldPrioritizeDependencies = self.prioritizeDependencies
        self.prioritizeDependencies.removeAll(keepingCapacity: true)
        for i in 0 ..< oldPrioritizeDependencies.count {
            try oldPrioritizeDependencies[i].resolveDependencies(into: &self.prioritizeDependencies, externalDependencies: externalDependencies)
        }
    }

    mutating func resolveGlobs(isExternal: Bool, projectType: Project.ProjectType, checkFilesExist: Bool) throws {
        for i in 0 ..< self.buildableFolders.count {
            try self.buildableFolders[i].resolveGlobs(isExternal: isExternal, checkFilesExist: checkFilesExist)
        }

        let oldAdditionalFiles = self.additionalFiles
        self.additionalFiles.removeAll(keepingCapacity: true)
        for i in 0 ..< oldAdditionalFiles.count {
            try oldAdditionalFiles[i].resolveGlobs(
                into: &self.additionalFiles,
                isExternal: isExternal, checkFilesExist: checkFilesExist
            )
        }

        for i in 0 ..< self.sources.count {
            try self.sources[i].resolveGlobs(isExternal: isExternal, checkFilesExist: checkFilesExist)
        }

        let oldResources = self.resources
        self.resources.removeAll(keepingCapacity: true)
        for i in 0 ..< oldResources.count {
            try oldResources[i].resolveGlobs(
                into: &self.resources,
                isExternal: isExternal,
                checkFilesExist: checkFilesExist,
                projectType: projectType,
                includeFiles: Target.isResource
            )
        }

        for i in 0 ..< copyFiles.count {
            try copyFiles[i].resolveGlobs(isExternal: isExternal, checkFilesExist: checkFilesExist)
        }

        for i in 0 ..< (headers?.list.count ?? 0) {
            try headers?.list[i].resolveGlobs(isExternal: isExternal, checkFilesExist: checkFilesExist)
        }

        for i in 0 ..< coreDataModels.count {
            try coreDataModels[i].resolveGlobs()
        }

        for i in 0 ..< self.scripts.count {
            try self.scripts[i].resolveGlobs(isExternal: isExternal, checkFilesExist: checkFilesExist)
        }
    }

    /// Applies fixes to properties of Target
    ///
    /// - moves playgrounds from sources and resources to `playgrounds`
    /// - moves xcdatamodeld from `resources` to `coreDataModels`
    /// - TODO: moves headers from `sources` to `headers`
    /// - resolves headers (see `Headers.applyFixits` for more info)
    mutating func applyFixits() throws {
        var playgrounds = Set(self.playgrounds)
        var extractedHeaders: [PlatformCondition?: [AbsolutePath]] = [:]

        for i in 0 ..< self.sources.count {
            let (extractedPlaygrounds, headers) = self.sources[i].extractPlaygroundsAndHeaders()

            playgrounds.formUnion(extractedPlaygrounds)

            let condition = self.sources[i].compilationCondition
            extractedHeaders[condition, default: []].append(contentsOf: headers)
        }

        let oldResources = self.resources
        var resourceDataModels: [AbsolutePath] = []
        self.resources.removeAll(keepingCapacity: true)
        for i in 0 ..< oldResources.count {
            switch oldResources[i] {
            case .folderReference:
                self.resources.append(oldResources[i])
            case let .file(path, _, _):
                switch path.extension {
                case "playground":
                    playgrounds.insert(path)
                case "xcdatamodeld":
                    resourceDataModels.append(path)
                default:
                    self.resources.append(oldResources[i])
                }
            case .glob:
                fatalError("Globs must be resolved before calling applyFixits() on Target")
            }
        }

        self.coreDataModels += try resourceDataModels.map { try CoreDataModel.from(path: $0) }
        self.playgrounds = Array(playgrounds)

        let productName = self.productName
        if !extractedHeaders.isEmpty && self.headers == nil {
            self.headers = HeadersList(list: [])
        }
        for i in 0 ..< (headers?.list.count ?? 0) {
            let platformCondition = headers?.list[i].compilationCondition

            if let headersFromSources = extractedHeaders[platformCondition] {
                extractedHeaders[platformCondition] = nil

                headers?.list[i].addHeaders(headersFromSources)
            }

            try headers?.list[i].applyFixits(productName: productName)
        }

        // any headers from sources that are not compatible
        // with existing header lists by platform condition
        // are going into new header lists with project scope

        for (platformCondition, platformHeaders) in extractedHeaders {
            headers?.list.append(
                Headers(
                    project: HeaderFileList.list(platformHeaders),
                    exclusionRule: .projectExcludesPrivateAndPublic,
                    compilationCondition: platformCondition
                )
            )
        }
    }
}

extension BuildableFolder {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        self.path = try generatorPaths.resolve(path: self.path)

        for i in 0 ..< self.exceptions.count {
            self.exceptions[i] = try generatorPaths.resolve(path: self.exceptions[i])
        }
    }

    mutating func resolveGlobs(isExternal: Bool, checkFilesExist: Bool) throws {
        self.exceptions = try FileHandler.shared.glob(
            self.exceptions, excluding: [],
            errorLevel: isExternal ? .error : .warning,
            checkFilesExist: checkFilesExist
        )
    }
}

extension SourceFiles {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        for i in 0 ..< self.paths.count {
            self.paths[i] = try generatorPaths.resolve(path: self.paths[i])
        }
        for i in 0 ..< self.excluding.count {
            self.excluding[i] = try generatorPaths.resolve(path: self.excluding[i])
        }
    }

    mutating func resolveGlobs(isExternal: Bool, checkFilesExist: Bool) throws {
        self.paths = try FileHandler.shared.glob(
            paths, excluding: excluding,
            errorLevel: isExternal ? .warning : .error,
            checkFilesExist: checkFilesExist
        )

        self.excluding = []
    }

    mutating func extractPlaygroundsAndHeaders() -> (playgrounds: [AbsolutePath], headers: [AbsolutePath]) {
        var playgrounds: [AbsolutePath] = []
        var headers: [AbsolutePath] = []

        paths.removeAll(where: { path in
            guard let ext = path.extension?.lowercased() else { return true }
            if ext == "playground" {
                playgrounds.append(path)
                return true
            } else if Target.validHeaderExtensions.contains(ext) {
                headers.append(path)
                return true
            }

            if !Target.validSourceExtensions.contains(ext) {
                return true
            }

            return path.isInOpaqueDirectory
        })

        return (playgrounds, headers)
    }
}
