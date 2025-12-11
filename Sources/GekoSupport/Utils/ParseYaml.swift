import Foundation
import ProjectDescription
import Yams

enum ParseYamlError: FatalError {
    case parseYamlError(context: String, errorContext: String)

    var type: ErrorType { .abort }

    var description: String {
        switch self {
        case let .parseYamlError(context, errorContext):
            return "An error occured while parsing \(context).\n\(errorContext)"
        }
    }
}

public enum ParseYamlContext {
    case file(path: AbsolutePath)
    case git(path: RelativePath, ref: String)

    var description: String {
        switch self {
        case let .file(path):
            return "file \(path)"
        case let .git(path, ref):
            return "file \(path) at \(ref)"
        }
    }
}

private let decoder = YAMLDecoder()

public func parseYaml<T: Decodable>(_ data: Data, context: ParseYamlContext) throws -> T {
    do {
        return try decoder.decode(from: data)
    } catch let error as Swift.DecodingError {
        var errorContext = "Unknown error"

        switch error {
        case let .dataCorrupted(context),
            let .keyNotFound(_, context),
            let .typeMismatch(_, context),
            let .valueNotFound(_, context):
            if let yamlError = context.underlyingError as? YamlError {
                errorContext = yamlError.description
            }
        @unknown default:
            break
        }

        throw ParseYamlError.parseYamlError(
            context: context.description,
            errorContext: errorContext
        )
    }
}
