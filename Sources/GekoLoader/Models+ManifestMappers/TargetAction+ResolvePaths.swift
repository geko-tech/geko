import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension TargetScript {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        switch self.script {
        case .embedded, .tool: break
        case let .scriptPath(path, arguments):
            let scriptPath = try generatorPaths.resolve(path: path)
            self.script = .scriptPath(path: scriptPath, args: arguments)
        }

        try self.inputPaths.resolvePaths(generatorPaths: generatorPaths)
        try self.outputPaths.resolvePaths(generatorPaths: generatorPaths)
        for i in 0 ..< self.inputFileListPaths.count {
            self.inputFileListPaths[i] = try generatorPaths.resolve(path: self.inputFileListPaths[i])
        }
        for i in 0 ..< self.outputFileListPaths.count {
            self.outputFileListPaths[i] = try generatorPaths.resolve(path: self.outputFileListPaths[i])
        }

        if let dependencyFile = self.dependencyFile {
            self.dependencyFile = try generatorPaths.resolve(path: dependencyFile)
        }
    }

    mutating func resolveGlobs(isExternal: Bool, checkFilesExist: Bool) throws {
        try self.inputPaths.resolveGlobs(isExternal: isExternal, checkFilesExist: checkFilesExist)
        // do not check output paths of scripts, because they can be created later
        try self.outputPaths.resolveGlobs(isExternal: isExternal, checkFilesExist: false)

        self.inputFileListPaths = try self.inputFileListPaths
            .resolveGlobsExceptPathsWithVariables(isExternal: isExternal, checkFilesExist: checkFilesExist)
        self.outputFileListPaths = try self.outputFileListPaths
            .resolveGlobsExceptPathsWithVariables(isExternal: isExternal, checkFilesExist: checkFilesExist)

        if let dependencyFile = self.dependencyFile {
            self.dependencyFile = try FileHandler.shared.glob(
                [dependencyFile], excluding: [],
                errorLevel: isExternal ? .warning : .error,
                checkFilesExist: checkFilesExist
            ).first
        }
    }
}

extension Array where Element == AbsolutePath {
    func resolveGlobsExceptPathsWithVariables(isExternal: Bool, checkFilesExist: Bool) throws -> [AbsolutePath] {
        var result: [AbsolutePath] = []
        var globs: [AbsolutePath] = []

        for i in 0 ..< self.count {
            if self[i].pathString.contains("$") {
                result.append(self[i])
            } else {
                globs.append(self[i])
            }
        }

        result.append(
            contentsOf: try FileHandler.shared.glob(
                globs, excluding: [],
                errorLevel: isExternal ? .warning : .error,
                checkFilesExist: checkFilesExist
            )
        )

        return result
    }
}
