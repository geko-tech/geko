import Foundation

extension String {

    var uint8: [UInt8] {
        [UInt8](self.utf8)
    }

    var canonicHeaderValue: String {
        trim().removeSequentialWhitespace()
    }

    func uriEncode() -> String {
        addingPercentEncoding(withAllowedCharacters: String.uriAllowedWithSlashCharacters) ?? self
    }

    func queryEncode() -> String {
        addingPercentEncoding(withAllowedCharacters: String.queryAllowedCharacters) ?? self
    }

    func removeSequentialWhitespace() -> String {
        reduce(into: "") { result, character in
            if result.last?.isWhitespace != true || character.isWhitespace == false {
                result.append(character)
            }
        }
    }

    func trim() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func trimmingQuotes() -> String {
        trimmingCharacters(in: .init(charactersIn: "\""))
    }

    static let uriAllowedWithSlashCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~/")
    static let queryAllowedCharacters = CharacterSet(charactersIn: "/;+").inverted
}
