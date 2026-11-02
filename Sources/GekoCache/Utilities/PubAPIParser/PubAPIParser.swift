import ProjectDescription
import GekoPubParser
import GekoSupport

enum PublicAPIParserError: FatalError {
    case invalidPath
    case outOfMemory
    case fileOpenFailed
    case parsingFailed
    case invalidUTF8
    case unknown(Int)
    
    var type: ErrorType {
        return .abort
    }
    
    var description: String {
        switch self {
        case .invalidPath:
            return "Invalid Swift source file path."
        case .outOfMemory:
            return "Failed to allocate memory for the Public API parser."
        case .fileOpenFailed:
            return "Failed to open Swift source file."
        case .parsingFailed:
            return "Failed to parse the public interface of the Swift source file."
        case .invalidUTF8:
            return "Public API parser returned invalid UTF-8 data."
        case let .unknown(code):
            return "Public API parser failed with an unknown error code: \(code)."
        }
    }
}

enum PublicAPIParseResult: Equatable {
    case safe(interface: String)
    case unsafe(reason: String)
}

    
final class PublicAPIParser {

    func parse(filePath: AbsolutePath) throws -> PublicAPIParseResult {
        guard filePath.url.isFileURL else {
            throw PublicAPIParserError.invalidPath
        }

        var result = filePath.url.withUnsafeFileSystemRepresentation { path in
            geko_public_api_parse(path)
        }

        defer {
            geko_public_api_result_free(&result)
        }

        switch result.status {
        case GEKO_PUB_PARSER_SAFE:
            guard let text = result.text else {
                return .safe(interface: "")
            }

            let bytes = UnsafeBufferPointer(
                start: UnsafeRawPointer(text).assumingMemoryBound(to: UInt8.self),
                count: Int(result.length)
            )

            guard let interface = String(bytes: bytes, encoding: .utf8) else {
                throw PublicAPIParserError.invalidUTF8
            }

            return .safe(interface: interface)

        case GEKO_PUB_PARSER_UNSAFE:
            let reason: String

            switch result.reason_code {
            case GEKO_PUB_PARSER_REASON_UNSUPPORTED_SYNTAX:
                reason = "Unsupported Swift syntax."
            default:
                reason = "Unknown unsafe reason."
            }

            return .unsafe(reason: reason)

        case GEKO_PUB_PARSER_ERROR:
            switch result.error_code {
            case 1:
                throw PublicAPIParserError.invalidPath
            case 2:
                throw PublicAPIParserError.outOfMemory
            case 3:
                throw PublicAPIParserError.fileOpenFailed
            case 4:
                throw PublicAPIParserError.parsingFailed
            default:
                throw PublicAPIParserError.unknown(Int(result.error_code))
            }

        default:
            throw PublicAPIParserError.unknown(Int(result.status.rawValue))
        }
    }
}

