public enum GlobNDFAError: Error, Equatable, CustomStringConvertible {
    case unbalancedBraces
    case unbalancedBrackets
    case invalidUtf8
    case expectedHyphen
    case differentCodepointLengthInRange(String)
    case backslashNothing
    case commaOutsideOfBraces

    public var description: String {
        switch self {
        case .unbalancedBraces:
            return "Unexpected end while processing alteration '{}' in glob pattern"
        case .unbalancedBrackets:
            return "Unexpected end while processing character set '[]' in glob pattern"
        case .invalidUtf8:
            return "Encountered invalid utf8 sequence while processing glob pattern"
        case .expectedHyphen:
            return "Expected '-' after first character while processing character set '[]'"
        case .differentCodepointLengthInRange(let range):
            return "Encountered variable utf8 codepoint length in range '\(range)'. Different lengths for codepoints in range are not supported"
        case .backslashNothing:
            return "Backslash '\' at the end of the pattern does not escape any character"
        case .commaOutsideOfBraces:
            return "Encountered comma ',' outside of braces '{}'. Use backslash to escape a character '\\,' if you need to match comma exactly."
        }
    }
}

public enum GlobSetError: Error, Equatable, CustomStringConvertible {
    case globError(pattern: String, error: GlobNDFAError)

    public var description: String {
        switch self {
        case let .globError(pattern, error):
            return "Error while parsing glob pattern '\(pattern)': \(error.description)"
        }
    }
}
