import Foundation
import GekoSupport
import GekoGraph
import ProjectDescription

protocol TargetImportsScanning {
    func imports(
        for target: Target,
        sideEffects: [SideEffectDescriptor]
    ) async throws -> Set<String>
}

final class TargetImportsScanner: TargetImportsScanning {
    // MARK: - Attributes

    private let importSourceCodeScanner: ImportSourceCodeScanner
    private let fileHandler: FileHandling

    // MARK: - Initialization

    init(
        importSourceCodeScanner: ImportSourceCodeScanner = ImportSourceCodeScanner(),
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.importSourceCodeScanner = importSourceCodeScanner
        self.fileHandler = fileHandler
    }

    // MARK: - TargetImportsScanning

    func imports(
        for target: Target,
        sideEffects: [SideEffectDescriptor]
    ) async throws -> Set<String> {
        let sideEffectsFiles: Set<AbsolutePath> = Set(sideEffects.compactMap { sideEffect in
            guard case let .file(fileDescriptor) = sideEffect else { return nil }
            return fileDescriptor.path
        })

        var filesToScan: [AbsolutePath] = []
        for sourceFiles in target.sources {
            for source in sourceFiles.paths {
                guard !sideEffectsFiles.contains(source) else { continue }

                filesToScan.append(source)
            }
        }
        if let headers = target.headers {
            headers.list.forEach {
                filesToScan.append(contentsOf: $0.private?.files ?? [])
                filesToScan.append(contentsOf: $0.public?.files ?? [])
                filesToScan.append(contentsOf: $0.project?.files ?? [])
            }
        }
        var imports = Set(
            try await filesToScan.concurrentMap(maxConcurrentTasks: 100) { file in
                try self.matchPattern(at: file)
            }
            .flatMap { $0 }
        )
        imports.remove(target.productName)

        return imports
    }

    // MARK: - Private

    private func matchPattern(at path: AbsolutePath) throws -> Set<String> {
        let programmingLanguage: ProgrammingLanguage
        switch path.extension {
        case "swift":
            programmingLanguage = .swift
        case "h", "m", "cpp", "mm":
            programmingLanguage = .objc
        default:
            return []
        }
        
        let sourceCode = try fileHandler.readTextFile(path)
        return try importSourceCodeScanner.extractImports(
            from: sourceCode,
            language: programmingLanguage
        )
    }
}
