import Foundation
import ProjectDescription

/// It represents th Info.plist contained in an .xcframework bundle.
public struct XCFrameworkInfoPlist: Codable, Hashable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case libraries = "AvailableLibraries"
    }

    /// It represents a library inside an .xcframework
    public struct Library: Codable, Hashable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case identifier = "LibraryIdentifier"
            case path = "LibraryPath"
            case architectures = "SupportedArchitectures"
            case mergeable = "MergeableMetadata"
            case platform = "SupportedPlatform"
            case platformVariant = "SupportedPlatformVariant"
        }

        /// It represents the library's platform.
        public enum Platform: String, Hashable, Codable {
            case ios
            case tvos
            case macos
            case watchos
            case visionos = "xros" // Note: for visionOS, the rawValue is 'xros'
        }

        public enum PlatformVariant: String, Hashable, Codable {
            case simulator
            case maccatalyst
        }

        /// Binary name used to import the library
        public var binaryName: String {
            path.basenameWithoutExt
        }

        /// Library identifier.
        public let identifier: String

        /// Path to the library.
        public let path: RelativePath

        /// Declares if the library is mergeable or not
        public let mergeable: Bool

        /// Architectures the binary is built for.
        public let architectures: [BinaryArchitecture]

        public let platform: Platform
        public let platformVariant: PlatformVariant?

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(identifier, forKey: .identifier)
            try container.encode(path, forKey: .path)
            try container.encode(mergeable, forKey: .mergeable)
            try container.encode(architectures, forKey: .architectures)
            try container.encode(platform, forKey: .platform)
            try container.encodeIfPresent(platformVariant, forKey: .platformVariant)
        }

        public init(
            identifier: String,
            path: RelativePath,
            mergeable: Bool,
            architectures: [BinaryArchitecture],
            platform: Platform,
            platformVariant: PlatformVariant?
        ) {
            self.identifier = identifier
            self.path = path
            self.mergeable = mergeable
            self.architectures = architectures
            self.platform = platform
            self.platformVariant = platformVariant
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            identifier = try container.decode(String.self, forKey: .identifier)
            path = try container.decode(RelativePath.self, forKey: .path)
            architectures = try container.decode([BinaryArchitecture].self, forKey: .architectures)
            mergeable = try container.decodeIfPresent(Bool.self, forKey: .mergeable) ?? false
            platform = try container.decode(Platform.self, forKey: .platform)
            platformVariant = try container.decodeIfPresent(PlatformVariant.self, forKey: .platformVariant)
        }
    }

    /// List of libraries that are part of the .xcframework.
    public let libraries: [Library]
    public let searchPathPlatforms: [String: RelativePath]

    public init(libraries: [Library], searchPathPlatforms: [String: RelativePath]) {
        self.libraries = libraries
        self.searchPathPlatforms = searchPathPlatforms
    }

    public init(from decoder: any Decoder) throws {
        let decoder = try decoder.container(keyedBy: CodingKeys.self)
        self.libraries = try decoder.decode([Library].self, forKey: .libraries)

        self.searchPathPlatforms = try Self.searchPathPlatforms(from: libraries)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(libraries, forKey: .libraries)
    }
}

extension XCFrameworkInfoPlist {
    public static func searchPathPlatforms(from libraries: [Library]) throws -> [String: RelativePath] {
        var result: [String: RelativePath] = [:]

        for library in libraries {
            let libraryPath = try RelativePath(validating: library.identifier)
                .appending(library.path)

            switch (library.platform, library.platformVariant) {
            case (.ios, nil):
                result["iphoneos"] = libraryPath
            case (.ios, .simulator):
                result["iphonesimulator"] = libraryPath
            case (.ios, .maccatalyst):
                // TODO: Xcode does not allow to create build setting for maccatalyst variant
                continue
            case (.tvos, nil):
                result["appletvos"] = libraryPath
            case (.tvos, .simulator):
                result["appletvsimulator"] = libraryPath
            case (.macos, nil):
                result["macosx"] = libraryPath
            case (.watchos, nil):
                result["watchos"] = libraryPath
            case (.watchos, .simulator):
                result["watchsimulator"] = libraryPath
            case (.visionos, nil):
                result["xros"] = libraryPath
            case (.visionos, .simulator):
                result["xrsimulator"] = libraryPath
            // TODO: Support for driverkit
            // result["driverkit"]
            default:
                break
            }
        }

        return result
    }
}
