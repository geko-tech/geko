import Foundation
import GekoCore
import GekoSupport
import XcbeautifyLib

protocol Formatting {
    func format(_ line: String) -> String?

    func format(
        line: String,
        output: @escaping (String, OutputType) throws -> Void
    ) throws
}

final class Formatter: Formatting {
    // MARK: - Attributes

    private let parser: Parser
    private let rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator()

    // MARK: - Initialization

    init() {
        parser = Parser(
            colored: Environment.shared.shouldOutputBeColoured,
            renderer: Self.renderer(),
            additionalLines: { nil }
        )
    }

    // MARK: - Formatting

    func format(_ line: String) -> String? {
        guard let parsed = parser.parse(line: line) else { return nil }
        if parser.outputType == .error {
            return formatError(parsed)
        }
        return parsed
    }

    func format(
        line: String,
        output: @escaping (String, OutputType) throws -> Void
    ) throws {
        guard let formatted = parser.parse(line: line) else { return }
        if parser.outputType == .error {
            return try output(formatError(formatted), parser.outputType)
        }
        try output(formatted, parser.outputType)
    }

    // MARK: - Helpers
    
    private func formatError(_ line: String) -> String {
        let rootDir = rootDirectoryLocator.locate(from: FileHandler.shared.currentPath)?.pathString ?? ""
        let formattedError = line
            .replacingOccurrences(of: "\(rootDir)/", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Default case of string processing with file path and error
        // Example: path/to/file.swift:14:5 error: some compiler error
        let lines = formattedError.components(separatedBy: .newlines)
        if lines.count == 3 {
            let firstLineComponents = lines[0].components(separatedBy: ": ")
            guard firstLineComponents.count == 2 else { return formattedError }

            let path = firstLineComponents[0]
            return formattedError.replacingOccurrences(of: path, with: path.yellow())
        }
        
        return formattedError
    }

    private static func renderer() -> Renderer {
        if Environment.shared.isGitHubActions {
            return .gitHubActions
        } else {
            return .terminal
        }
    }
}
