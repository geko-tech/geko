import Foundation

enum GlobalError: FatalError {
    case projectNotSelected
    case fileNotFound(fileName: String)
    case decodingError(info: String)
    
    var errorDescription: String? {
        switch self {
        case .projectNotSelected:
            "The project has not been selected. Please select a project before continuing"
        case .fileNotFound(let fileName):
            "\(fileName) not found"
        case .decodingError(let info):
            info
        }
    }

    var type: FatalErrorType {
        .abort
    }
}

extension GlobalError {
    static func from(decodingError: DecodingError, entity: Any.Type) -> GlobalError {
        switch decodingError {
        case .typeMismatch(let type, _):
            .decodingError(info: "Decoding error \(String(describing: entity)): type mismatch \(String(describing: type))")
        case .valueNotFound(let value, _):
            .decodingError(info: "Decoding error \(String(describing: entity)): value not found \(String(describing: value))")
        case .keyNotFound(let key, _):
            .decodingError(info: "Decoding error \(String(describing: entity)): key not found \(String(describing: key))")
        case .dataCorrupted(_):
            .decodingError(info: "Decoding error \(String(describing: entity)): data corrupted")
        @unknown default:
            .decodingError(info: "Decoding error \(String(describing: entity)): unknown")
        }
    }
}
