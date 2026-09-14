import GekoSupport
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

public protocol TargetOwnershipOutputRendering {
    func render(
        _ ownerships: [FileTargetOwnership],
        rootPath: AbsolutePath,
        infoMessage: String
    )
}

/// Renders file ownership results consistently for human and structured output.
public final class TargetOwnershipOutputRenderer: TargetOwnershipOutputRendering {
    public init() {}

    public func render(
        _ ownerships: [FileTargetOwnership],
        rootPath: AbsolutePath,
        infoMessage: String
    ) {
        let output = makeOutput(ownerships: ownerships, rootPath: rootPath)

        consoleOutput(
            for: ownerships,
            rootPath: rootPath,
            header: infoMessage
        )
        CommandOutputStore.shared.set(.targetOwnership, value: output)
    }

    private func consoleOutput(
        for ownerships: [FileTargetOwnership],
        rootPath: AbsolutePath,
        header: String
    ) {
        let ownershipOutput = ownerships.map { ownership in
            let path = ownership.file.relative(to: rootPath).pathString
            let targets = ownership.targets.map(\.target.name)
            return "\(path): \(targets.isEmpty ? "<no targets found>" : targets.joined(separator: ", "))"
        }.joined(separator: "\n")
        logger.notice(Logger.Message(stringLiteral: header))
        logger.info(Logger.Message(stringLiteral: ownershipOutput))
    }

    private func makeOutput(
        ownerships: [FileTargetOwnership],
        rootPath: AbsolutePath
    ) -> TargetsOutput {
        TargetsOutput(
            files: ownerships.map { ownership in
                FileOwnershipOutput(
                    path: ownership.file.relative(to: rootPath).pathString,
                    targets: ownership.targets.map { target in
                        TargetOutput(
                            name: target.target.name,
                            projectPath: target.path
                                .relative(to: rootPath)
                                .pathString
                        )
                    }
                )
            }
        )
    }
}
