import ProjectDescription

/// An error that occurs during the creation of a version.
public enum VersionError: Error, CustomStringConvertible {
    /// The version string contains non-ASCII characters.
    /// - Parameter versionString: The version string.
    case nonASCIIVersionString(_ versionString: String)
    /// The version core contains an invalid number of Identifiers.
    /// - Parameters:
    ///   - identifiers: The version core identifiers in the version string.
    ///   - usesLenientParsing: A Boolean value indicating whether or not the lenient parsing mode was enabled when this error occurred.
    case invalidVersionCoreIdentifiersCount(_ identifiers: [String], usesLenientParsing: Bool)
    /// Some or all of the version core identifiers contain non-numerical characters or are empty.
    /// - Parameter identifiers: The version core identifiers in the version string.
    case nonNumericalOrEmptyVersionCoreIdentifiers(_ identifiers: [String])
    /// Some or all of the pre-release identifiers contain characters other than alpha-numerics and hyphens.
    /// - Parameter identifiers: The pre-release identifiers in the version string.
    case nonAlphaNumerHyphenalPrereleaseIdentifiers(_ identifiers: [String])
    /// Some or all of the build metadata identifiers contain characters other than alpha-numerics and hyphens.
    /// - Parameter identifiers: The build metadata identifiers in the version string.
    case nonAlphaNumerHyphenalBuildMetadataIdentifiers(_ identifiers: [String])

    public var description: String {
        switch self {
        case let .nonASCIIVersionString(versionString):
            return "non-ASCII characters in version string '\(versionString)'"
        case let .invalidVersionCoreIdentifiersCount(identifiers, usesLenientParsing):
            return "\(identifiers.count > 3 ? "more than 3" : "fewer than \(usesLenientParsing ? 2 : 3)") identifiers in version core '\(identifiers.joined(separator: "."))'"
        case let .nonNumericalOrEmptyVersionCoreIdentifiers(identifiers):
            if !identifiers.allSatisfy( { !$0.isEmpty } ) {
                return "empty identifiers in version core '\(identifiers.joined(separator: "."))'"
            } else {
                // Not checking for `.isASCII` here because non-ASCII characters should've already been caught before this.
                let nonNumericalIdentifiers = identifiers.filter { !$0.allSatisfy(\.isNumber) }
                return "non-numerical characters in version core identifier\(nonNumericalIdentifiers.count > 1 ? "s" : "") \(nonNumericalIdentifiers.map { "'\($0)'" } .joined(separator: ", "))"
            }
        case let .nonAlphaNumerHyphenalPrereleaseIdentifiers(identifiers):
            // Not checking for `.isASCII` here because non-ASCII characters should've already been caught before this.
            let nonAlphaNumericalIdentifiers = identifiers.filter { !$0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } }
            return "characters other than alpha-numerics and hyphens in pre-release identifier\(nonAlphaNumericalIdentifiers.count > 1 ? "s" : "") \(nonAlphaNumericalIdentifiers.map { "'\($0)'" } .joined(separator: ", "))"
        case let .nonAlphaNumerHyphenalBuildMetadataIdentifiers(identifiers):
            // Not checking for `.isASCII` here because non-ASCII characters should've already been caught before this.
            let nonAlphaNumericalIdentifiers = identifiers.filter { !$0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } }
            return "characters other than alpha-numerics and hyphens in build metadata identifier\(nonAlphaNumericalIdentifiers.count > 1 ? "s" : "") \(nonAlphaNumericalIdentifiers.map { "'\($0)'" } .joined(separator: ", "))"
        }
    }
}

extension ProjectDescription.Version {
    // TODO: Rename this function to `init(string:usesLenientParsing:) throws`, after `init?(string: String)` is removed.
    // TODO: Find a better error-checking order.
    // Currently, if a version string is "forty-two", this initializer throws an error that says "forty" is only 1 version core identifier, which is not enough.
    // But this is misleading the user to consider "forty" as a valid version core identifier.
    // We should find a way to check for (or throw) "wrong characters used" errors first, but without overly-complicating the logic.
    /// Creates a version from the given string.
    /// - Parameters:
    ///   - versionString: The string to create the version from.
    ///   - usesLenientParsing: A Boolean value indicating whether or not the version string should be parsed leniently. If `true`, then the patch version is assumed to be `0` if it's not provided in the version string; otherwise, the parsing strictly follows the Semantic Versioning 2.0.0 rules. This value defaults to `false`.
    /// - Throws: A `VersionError` instance if the `versionString` doesn't follow [SemVer 2.0.0](https://semver.org).
    public init(versionString: String, usesLenientParsing: Bool = false) throws {
        // SemVer 2.0.0 allows only ASCII alphanumerical characters and "-" in the version string, except for "." and "+" as delimiters. ("-" is used as a delimiter between the version core and pre-release identifiers, but it's allowed within pre-release and metadata identifiers as well.)
        // Alphanumerics check will come later, after each identifier is split out (i.e. after the delimiters are removed).
        guard versionString.allSatisfy(\.isASCII) else {
            throw VersionError.nonASCIIVersionString(versionString)
        }

        let metadataDelimiterIndex = versionString.firstIndex(of: "+")
        // SemVer 2.0.0 requires that pre-release identifiers come before build metadata identifiers
        let prereleaseDelimiterIndex = versionString[..<(metadataDelimiterIndex ?? versionString.endIndex)].firstIndex(of: "-")

        let versionCore = versionString[..<(prereleaseDelimiterIndex ?? metadataDelimiterIndex ?? versionString.endIndex)]
        let versionCoreIdentifiers = versionCore.split(separator: ".", omittingEmptySubsequences: false)

        guard versionCoreIdentifiers.count == 3 || (usesLenientParsing && versionCoreIdentifiers.count == 2) else {
            throw VersionError.invalidVersionCoreIdentifiersCount(versionCoreIdentifiers.map { String($0) }, usesLenientParsing: usesLenientParsing)
        }

        guard
            // Major, minor, and patch versions must be ASCII numbers, according to the semantic versioning standard.
            // Converting each identifier from a substring to an integer doubles as checking if the identifiers have non-numeric characters.
            let major = Int(versionCoreIdentifiers[0]),
            let minor = Int(versionCoreIdentifiers[1]),
            let patch = usesLenientParsing && versionCoreIdentifiers.count == 2 ? 0 : Int(versionCoreIdentifiers[2])
        else {
            throw VersionError.nonNumericalOrEmptyVersionCoreIdentifiers(versionCoreIdentifiers.map { String($0) })
        }

        let prereleaseIdentifiers: [String]
        if let prereleaseDelimiterIndex = prereleaseDelimiterIndex {
            let prereleaseStartIndex = versionString.index(after: prereleaseDelimiterIndex)
            let identifiers = versionString[prereleaseStartIndex..<(metadataDelimiterIndex ?? versionString.endIndex)].split(separator: ".", omittingEmptySubsequences: false)
            guard identifiers.allSatisfy( { $0.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) } ) else {
                throw VersionError.nonAlphaNumerHyphenalPrereleaseIdentifiers(identifiers.map { String($0) })
            }
            prereleaseIdentifiers = identifiers.map { String($0) }
        } else {
            prereleaseIdentifiers = []
        }

        let buildMetadataIdentifiers: [String]
        if let metadataDelimiterIndex = metadataDelimiterIndex {
            let metadataStartIndex = versionString.index(after: metadataDelimiterIndex)
            let identifiers = versionString[metadataStartIndex...].split(separator: ".", omittingEmptySubsequences: false)
            guard identifiers.allSatisfy( { $0.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) } ) else {
                throw VersionError.nonAlphaNumerHyphenalBuildMetadataIdentifiers(identifiers.map { String($0) })
            }
            buildMetadataIdentifiers = identifiers.map { String($0) }
        } else {
            buildMetadataIdentifiers = []
        }

        self.init(major, minor, patch, prereleaseIdentifiers: prereleaseIdentifiers, buildMetadataIdentifiers: buildMetadataIdentifiers)
    }

    public init?(_ versionString: String) {
        try? self.init(versionString: versionString)
    }
}
