import Foundation
import ProjectDescription

enum ParseJsonError: FatalError {
    case parseJsonError(context: String, errorContext: String)

    var type: ErrorType { .abort }

    var description: String {
        switch self {
        case let .parseJsonError(context, errorContext):
            return "An error occured while parsing \(context).\n\(errorContext)"
        }
    }
}

public enum ParseJsonContext {
    case file(path: AbsolutePath)
    case podspec(path: AbsolutePath)

    var description: String {
        switch self {
        case let .file(path):
            return "json file \(path)"
        case let .podspec(path):
            return "json from podspec file \(path).\nYou can review json yourself by using command 'pod ipc spec \(path)'"
        }
    }
}

private let decoder = JSONDecoder()

public func parseJson<T: Decodable>(_ data: Data, context: ParseJsonContext) throws -> T {
    do {
        return try decoder.decode(T.self, from: data)
    } catch let error as Swift.DecodingError {
        var errorContext = ""

        func pathDescription(for codingKeys: [any CodingKey]) -> String {
            var result = "'root"
            for key in codingKeys {
                if let int = key.intValue {
                    result += "[\(int)]"
                } else {
                    result += ".\(key.stringValue)"
                }
            }
            result += "'"

            return result
        }

        switch error {
        case let .dataCorrupted(decodeContext):
            let nsError = decodeContext.underlyingError as? NSError
            let debugDescription = nsError?.userInfo[NSDebugDescriptionErrorKey] as? String
            errorContext = debugDescription ?? ""

        case let .keyNotFound(key, context):
            if let int = key.intValue {
                errorContext = "Unable to find value at index \(int)"
            } else {
                errorContext = "Unable to find key '\(key.stringValue)`"
            }

            errorContext += " at path \(pathDescription(for: context.codingPath + [key]))."
        case let .typeMismatch(_, context):
            errorContext += "Type mismatch at path \(pathDescription(for: context.codingPath)). \(context.debugDescription)"
        case let .valueNotFound(type, context):
            errorContext += "Expected to find value of type \(type) but found 'null` instead at path \(pathDescription(for: context.codingPath))"
        @unknown default:
            errorContext = "Unknown error."
        }

        throw ParseJsonError.parseJsonError(
            context: context.description,
            errorContext: errorContext
        )
    }
}
