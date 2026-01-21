import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public enum CopyFilesManifestMapperError: FatalError {
    case invalidResourcesGlob(actionName: String, invalidGlobs: [InvalidGlob])

    public var type: ErrorType { .abort }

    public var description: String {
        switch self {
        case let .invalidResourcesGlob(actionName: actionName, invalidGlobs: invalidGlobs):
            return "The copy files action \(actionName) has the following invalid resource globs:\n" + invalidGlobs
                .invalidGlobsDescription
        }
    }
}

extension CopyFilesAction {
    /// - Parameters:
    ///   - isExternal: Indicates whether the project is imported through `Dependencies.swift`.
    mutating func resolvePaths(
        generatorPaths: GeneratorPaths
    ) throws {
        for i in 0 ..< self.files.count {
            try files[i].resolvePaths(generatorPaths: generatorPaths)
        }
    }

    mutating func resolveGlobs(isExternal: Bool, checkFilesExist: Bool) throws {
        var invalidResourceGlobs: [InvalidGlob] = []

        let oldFiles = self.files
        self.files.removeAll(keepingCapacity: true)

        for i in 0 ..< oldFiles.count {
            do {
                try oldFiles[i].resolveGlobs(
                    into: &self.files,
                    isExternal: isExternal,
                    checkFilesExist: checkFilesExist,
                    includeFiles: { Target.isResource(path: $0) }
                )
            } catch let FileHandlerError.nonExistentGlobDirectory(pattern, path) {
                invalidResourceGlobs.append(.init(pattern: pattern, nonExistentPath: path))
            }
        }

        if !invalidResourceGlobs.isEmpty {
            let error = CopyFilesManifestMapperError.invalidResourcesGlob(actionName: name, invalidGlobs: invalidResourceGlobs)
                throw error
        }

        self.files.cleanPackages()
    }
}

// MARK: - Array Extension FileElement

extension [FileElement] {
    /// Packages should be added as a whole folder not individually.
    /// (e.g. bundled file formats recognized by the OS like .pages, .numbers, .rtfd...)
    ///
    /// Given the input:
    /// ```
    /// /project/Templates/yellow.template/meta.json
    /// /project/Templates/yellow.template/image.png
    /// /project/Templates/blue.template/meta.json
    /// /project/Templates/blue.template/image.png
    /// /project/Fonts/somefont.ttf
    /// ```
    /// This is the output:
    /// ```
    /// /project/Templates/yellow.template
    /// /project/Templates/blue.template
    /// /project/Fonts/somefont.ttf
    /// ```
    ///
    /// - Returns: List of clean `AbsolutePath`s
    public mutating func cleanPackages() {
        removeAll(where: {
            var filePath = $0.path
            while !filePath.isRoot {
                if filePath.parentDirectory.isPackage {
                    return true
                } else if filePath.isPackage {
                    return false
                } else {
                    filePath = filePath.parentDirectory
                }
            }
            return false
        })
    }
}
