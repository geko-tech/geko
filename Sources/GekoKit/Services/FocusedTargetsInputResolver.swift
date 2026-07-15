import Foundation
import GekoSupport
import struct ProjectDescription.AbsolutePath

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

        let path = try AbsolutePath(
            validating: planPath,
            relativeTo: fileHandler.currentPath
        )
        let content = try fileHandler.readTextFile(path)
        return targets(from: content)
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
