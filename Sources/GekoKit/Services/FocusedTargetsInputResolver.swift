import Foundation
import GekoSupport
import struct ProjectDescription.AbsolutePath

enum FocusedTargetsInputResolverError: FatalError, Equatable {
    case conflictingInputs
    case planNotFound(AbsolutePath)
    case planIsDirectory(AbsolutePath)
    case unableToReadPlan(AbsolutePath, reason: String)
    case emptyPlan(AbsolutePath)

    var type: ErrorType { .abort }

    var description: String {
        switch self {
        case .conflictingInputs:
            return "Use either positional focused targets or --plan, not both."
        case let .planNotFound(path):
            return "The plan file was not found at \(path.pathString)."
        case let .planIsDirectory(path):
            return "Expected a plan file, but found a directory at \(path.pathString)."
        case let .unableToReadPlan(path, reason):
            return "Could not read the plan file at \(path.pathString): \(reason)"
        case let .emptyPlan(path):
            return "The plan file at \(path.pathString) does not contain any focused targets."
        }
    }
}

struct FocusedTargetsInputResolver {
    private let fileHandler: FileHandling

    init(fileHandler: FileHandling = FileHandler.shared) {
        self.fileHandler = fileHandler
    }

    func resolve(
        sources: [String],
        planPath: String?
    ) throws -> Set<String> {
        guard let planPath else {
            return Set(sources)
        }
        guard sources.isEmpty else {
            throw FocusedTargetsInputResolverError.conflictingInputs
        }

        let path = try AbsolutePath(
            validating: planPath,
            relativeTo: fileHandler.currentPath
        )
        guard fileHandler.exists(path) else {
            throw FocusedTargetsInputResolverError.planNotFound(path)
        }
        guard !fileHandler.isFolder(path) else {
            throw FocusedTargetsInputResolverError.planIsDirectory(path)
        }

        let content: String
        do {
            content = try fileHandler.readTextFile(path)
        } catch let error as FileHandlerError {
            throw error
        } catch {
            throw FocusedTargetsInputResolverError.unableToReadPlan(
                path,
                reason: String(describing: error)
            )
        }

        let targets = targets(from: content)
        guard !targets.isEmpty else {
            throw FocusedTargetsInputResolverError.emptyPlan(path)
        }
        return targets
    }

    private func targets(from content: String) -> Set<String> {
        Set(
            content
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter {
                    !$0.isEmpty &&
                        !$0.hasPrefix("#") &&
                        !$0.hasPrefix("//")
                }
        )
    }
}
