import Foundation
import ProjectDescription
import GekoGraph
import GekoSupport

extension FileList {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        for i in 0 ..< self.files.count {
            self.files[i] = try generatorPaths.resolve(path: self.files[i])
        }

        for i in 0 ..< self.excluding.count {
            self.excluding[i] = try generatorPaths.resolve(path: self.excluding[i])
        }
    }

    mutating func resolveGlobs(isExternal: Bool, checkFilesExist: Bool) throws {
        var dollarPaths: [AbsolutePath] = []
        var globPaths: [AbsolutePath] = []
        
        for i in 0 ..< self.files.count {
            if self.files[i].pathString.contains("$") {
                dollarPaths.append(self.files[i])
            } else {
                globPaths.append(self.files[i])
            }
        }

        self.files = dollarPaths
        try self.files.append(contentsOf: FileHandler.shared.glob(
            globPaths,
            excluding: self.excluding,
            errorLevel: isExternal ? .warning : .error,
            checkFilesExist: checkFilesExist
        ))
    }
}
