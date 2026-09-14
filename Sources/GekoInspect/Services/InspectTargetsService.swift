import Foundation
import GekoSupport
import GekoGraph
import ProjectDescription

private struct TargetsOutput: Encodable {
    let files: [FileOwnershipOutput]
}

private struct FileOwnershipOutput: Encodable {
    let path: String
    let targets: [TargetOutput]
}

private struct TargetOutput: Encodable {
    let name: String
    let projectPath: String
}

public protocol InspectTargetsServicing {
    func run(
        path: AbsolutePath,
        files: [String],
        graph: Graph,
        output: AbsolutePath?
    ) throws
}

public final class InspectTargetsService: InspectTargetsServicing {
    // MARK: - Attributes
    
    private let targetOwnershipResolver: TargetFileOwnershipResolving
    
    // MARK: - Init
    
    public convenience init() {
        self.init(targetOwnershipResolver: TargetFileOwnershipResolver())
    }
    
    public init(targetOwnershipResolver: TargetFileOwnershipResolving) {
        self.targetOwnershipResolver = targetOwnershipResolver
    }
    
    // MARK: - InspectTargetsServicing
    
    public func run(
        path: AbsolutePath,
        files: [String],
        graph: Graph,
        output: AbsolutePath?
    ) throws {
        let inputFiles = try files.map {
            try AbsolutePath(validating: $0, relativeTo: path)
        }
        let ownerships = try targetOwnershipResolver.resolve(inputFiles, graph: graph)
        
        if let output {
            try saveOutput(
                ownerships: ownerships,
                outputPath: output,
                rootPath: path
            )
        }
        
        consoleOutput(for: ownerships, rootPath: path)
    }
    
    // MARK: - Private
    
    private func consoleOutput(for ownership: [FileTargetOwnership], rootPath: AbsolutePath) {
        let output = "Targets containing the specified files:\n"
        let ownershipOutput = ownership.map { ownership in
            let path = ownership.file.relative(to: rootPath).pathString
            let targets = ownership.targets.map(\.target.name)
            return "\(path): \(targets.isEmpty ? "<no targets found>" : targets.joined(separator: ", "))"
        }.joined(separator: "\n")
        logger.notice(Logger.Message(stringLiteral: output))
        logger.info(Logger.Message(stringLiteral: ownershipOutput))
    }
    
    private func saveOutput(
        ownerships: [FileTargetOwnership],
        outputPath: AbsolutePath,
        rootPath: AbsolutePath
    ) throws {
        if FileHandler.shared.exists(outputPath) {
            try FileHandler.shared.delete(outputPath)
        }
        
        let output = TargetsOutput(files: ownerships.map { ownership in
            FileOwnershipOutput(
                path: ownership.file.relative(to: rootPath).pathString,
                targets: ownership.targets.map { target in
                    TargetOutput(
                        name: target.target.name,
                        projectPath: target.path.relative(to: rootPath).pathString
                    )
                }
            )
        })
        let jsonData = try JSONEncoder().encode(output)
        guard let content = String(data: jsonData, encoding: .utf8) else {
            throw FileHandlerError.invalidTextEncoding(outputPath)
        }

        try FileHandler.shared.createFolder(outputPath.parentDirectory)
        try FileHandler.shared.write(
            content,
            path: outputPath,
            atomically: true
        )
    }
}
