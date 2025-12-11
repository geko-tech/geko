import Foundation

private extension UInt8 {
    static let tab: UInt8 = 9 // '\t'
    static let newline: UInt8 = 10 // '\n'
    static let backslash: UInt8 = 92 // '\'
    static let underscore: UInt8 = 95 // '_'
    static let doubleQuotes: UInt8 = 34 // '"'
    static let dollar: UInt8 = 36 // '$'
    static let slash: UInt8 = 47 // '/'

    static let dot: UInt8 = 46 // '.'
    static let nine: UInt8 = 57 // '9'

    static let capitalA: UInt8 = 65 // 'A'
    static let capitalZ: UInt8 = 90 // 'Z'

    static let smallA: UInt8 = 97 // 'a'
    static let smallN: UInt8 = 110 // 'n'
    static let smallT: UInt8 = 116 // 't'
    static let smallZ: UInt8 = 122 // 'z'
}

/// String that includes a comment
struct CommentedString {
    /// Entity string value.
    let string: String

    /// String comment.
    let comment: String?

    /// Initializes the commented string with the value and the comment.
    ///
    /// - Parameters:
    ///   - string: string value.
    ///   - comment: comment.
    init(_ string: String, comment: String? = nil) {
        self.string = string
        self.comment = comment
    }


    /// Returns a valid string for Xcode projects.
    var validString: String {
        switch string {
        case "": return "\"\""
        case "false": return "NO"
        case "true": return "YES"
        default: break
        }

        var str = string
        return str.withUTF8 { buf -> String in
            var containsInvalidCharacters = false
            for ch in buf {
                // ch == '_' || ch <= '$'
                if ch == .underscore || ch == .dollar {
                    continue
                }
                // ch >= '.' && ch <= '9'
                if ch >= .dot && ch <= .nine {
                    continue
                }
                // ch >= 'A' && ch <= 'Z'
                if ch >= .capitalA && ch <= .capitalZ {
                    continue
                }
                // ch >= 'a' && ch <= 'z'
                if ch >= .smallA && ch <= .smallZ {
                    continue
                }
                containsInvalidCharacters = true
                break
            }

            if !containsInvalidCharacters {
                var containsSpecialCheckCharacters = false
                for ch in buf {
                    // ch == '_' || ch == '/'
                    if ch == .underscore || ch == .slash {
                        containsSpecialCheckCharacters = true
                        break
                    }
                }

                if !containsSpecialCheckCharacters {
                    return string
                } else if !string.contains("//"), !string.contains("___") {
                    return string
                }
            }

            var escaped: [UInt8] = []
            escaped.reserveCapacity(buf.count + 10)
            escaped.append(.doubleQuotes)

            for character in buf {
                switch character {
                case .backslash:
                    // "\\"
                    escaped.append(.backslash)
                    escaped.append(.backslash)
                case .doubleQuotes:
                    // "\""
                    escaped.append(.backslash)
                    escaped.append(.doubleQuotes)
                case .tab:
                    // "\\t""
                    escaped.append(.backslash)
                    escaped.append(.smallT)
                case .newline:
                    // "\\n""
                    escaped.append(.backslash)
                    escaped.append(.smallN)
                default:
                    // no need to escape character
                    escaped.append(character)
                }
            }

            escaped.append(.doubleQuotes)
            return String(bytes: escaped, encoding: .utf8)!
        }
    }
}

// MARK: - Hashable

extension CommentedString: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(string)
    }

    static func == (lhs: CommentedString, rhs: CommentedString) -> Bool {
        lhs.string == rhs.string && lhs.comment == rhs.comment
    }
}

// MARK: - ExpressibleByStringLiteral

extension CommentedString: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(value)
    }

    public init(unicodeScalarLiteral value: String) {
        self.init(value)
    }
}
