import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension Headers.ModuleMap {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        guard case let .file(path) = self else {
            return
        }

        self = .file(path: try generatorPaths.resolve(path: path))
    }
}

extension Headers {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        if let umbrella = self.umbrellaHeader {
            self.umbrellaHeader = try generatorPaths.resolve(path: umbrella)
        }

        try self.public?.resolvePaths(generatorPaths: generatorPaths)
        try self.private?.resolvePaths(generatorPaths: generatorPaths)
        try self.project?.resolvePaths(generatorPaths: generatorPaths)

        if let mappingsDir = self.mappingsDir {
            self.mappingsDir = try generatorPaths.resolve(path: mappingsDir)
        }

        try self.moduleMap?.resolvePaths(generatorPaths: generatorPaths)
    }

    mutating func resolveGlobs(isExternal: Bool, checkFilesExist: Bool) throws {
        try self.public?.resolveGlobs(isExternal: isExternal, checkFilesExist: checkFilesExist)
        try self.private?.resolveGlobs(isExternal: isExternal, checkFilesExist: checkFilesExist)
        try self.project?.resolveGlobs(isExternal: isExternal, checkFilesExist: checkFilesExist)
    }

    mutating func addHeaders(_ newHeaders: [AbsolutePath]) {
        switch self.exclusionRule {
        case .projectExcludesPrivateAndPublic:
            if self.project == nil {
                self.project = HeaderFileList.list([])
            }
            self.project?.files.append(contentsOf: newHeaders)
        case .publicExcludesPrivateAndProject:
            if self.public == nil {
                self.public = HeaderFileList.list([])
            }
            self.public?.files.append(contentsOf: newHeaders)
        }
    }

    /// Resolves headers using following rules
    ///
    /// - removes any files that do not have extensions from set `Target.headers.extensions`
    /// - removes any public headers from list, that does not appear in umbrella, if umbrella is present
    /// - resolves headers using `exclusionRule`
    mutating func applyFixits(productName: String) throws {
        let headersFromUmbrella = try self.umbrellaHeader.flatMap {
            // Umbrella header may be generated as a side effect,
            // in which case we do not need to modify public headers
            // based on umbrella.
            do {
                return Set(try UmbrellaHeaderHeadersExtractor.headers(from: $0, for: productName))
            } catch let error as CocoaError {
                switch error.code {
                case .fileReadNoSuchFile:
                    return nil
                default:
                    throw error
                }
            }
        }

        var exclude: Set<AbsolutePath> = []

        switch self.exclusionRule {
        case .projectExcludesPrivateAndPublic:
            self.public?.applyFixits(isPublic: true, exclude: exclude, umbrellaHeaders: headersFromUmbrella)
            // be sure, that umbrella was not added before
            if let umbrellaPath = self.umbrellaHeader, self.public?.files.contains(umbrellaPath) != true {
                if self.public == nil {
                    self.public = .init(globs: [])
                }
                self.public?.files.append(umbrellaPath)
            }
            exclude = Set(self.public?.files ?? [])

            self.private?.applyFixits(isPublic: false, exclude: exclude, umbrellaHeaders: nil)
            exclude.formUnion(self.private?.files ?? [])

            self.project?.applyFixits(isPublic: false, exclude: exclude, umbrellaHeaders: nil)

        case .publicExcludesPrivateAndProject:
            self.project?.applyFixits(isPublic: false, exclude: exclude, umbrellaHeaders: nil)
            exclude = Set(self.project?.files ?? [])

            self.private?.applyFixits(isPublic: false, exclude: exclude, umbrellaHeaders: nil)
            exclude.formUnion(self.private?.files ?? [])

            self.public?.applyFixits(isPublic: true, exclude: exclude, umbrellaHeaders: headersFromUmbrella)
            // be sure, that umbrella was not added before
            if let umbrellaPath = self.umbrellaHeader, self.public?.files.contains(umbrellaPath) != true {
                if self.public == nil {
                    self.public = .init(globs: [])
                }
                self.public?.files.append(umbrellaPath)
            }
        }
    }
}

extension HeaderFileList {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        for i in 0 ..< self.files.count {
            self.files[i] = try generatorPaths.resolve(path: self.files[i])
        }

        for i in 0 ..< (self.excluding?.count ?? 0) {
            self.excluding![i] = try generatorPaths.resolve(path: self.excluding![i])
        }
    }

    mutating func resolveGlobs(isExternal: Bool, checkFilesExist: Bool) throws {
        var globs = self.files
        var dollarPaths: [AbsolutePath] = []
        globs.removeAll(where: { path in
            if path.pathString.contains("$") {
                dollarPaths.append(path)
                return true
            }
            return false
        })

        self.files = try FileHandler.shared.glob(
            globs, excluding: self.excluding ?? [],
            errorLevel: isExternal ? .warning : .error,
            checkFilesExist: checkFilesExist
        ) + dollarPaths
    }

    mutating func applyFixits(
        isPublic: Bool,
        exclude: borrowing Set<AbsolutePath>,
        umbrellaHeaders: Set<String>?
    ) {
        self.files.removeAll(where: { [umbrellaHeaders] path in
            guard let fileExtension = path.extension?.lowercased(),
                Target.validHeaderExtensions.contains(fileExtension),
                !exclude.contains(path)
            else {
                return true
            }
            if isPublic, let umbrellaHeaders {
                return !umbrellaHeaders.contains(path.basename)
            }
            return false
        })
    }
}
