import Foundation
import GekoSupport
import GekoGraph
import ProjectDescription

public protocol SwiftModuleMetadataProviding {
    /// Parse given swiftmodule file name and tries to find metadata
    func loadMetadata(at path: AbsolutePath) throws -> SwiftModuleMetadata
}

enum SwiftModuleMetadataProviderError: FatalError, Equatable {
    case metadataNotFound(AbsolutePath)

    var description: String {
        switch self {
        case let .metadataNotFound(path):
            return "Couldn't find metadata for binary at path \(path.pathString)"
        }
    }

    var type: ErrorType {
        switch self {
        case .metadataNotFound:
            return .abort
        }
    }
}

public struct SwiftModuleMetadata: Equatable {
    public enum Platform: String, CaseIterable {
        case ios
        case macos
        case tvos
        case watchos
        case visionos
        
        var xcframeworkPlatform: XCFrameworkInfoPlist.Library.Platform {
            switch self {
            case .ios:
                return .ios
            case .macos:
                return .macos
            case .tvos:
                return .tvos
            case .watchos:
                return .watchos
            case .visionos:
                return .visionos
            }
        }
    }
    
    public enum PlatformVariant: String, CaseIterable {
        case simulator
        case maccatalyst = "macabi"
        
        var xcframeworkPlatformVariant: XCFrameworkInfoPlist.Library.PlatformVariant {
            switch self {
            case .simulator:
                return .simulator
            case .maccatalyst:
                return .maccatalyst
            }
        }
    }
    
    /// SwiftModule file name. Ex.: arm64-apple-ios-simulator.swiftmodule or arm64-apple-ios.swiftmodule
    public let fileName: String
    public let arch: BinaryArchitecture
    public let platform: Platform
    public let platformVariant: PlatformVariant?
}

public final class SwiftModuleMetadataProvider: SwiftModuleMetadataProviding {
    
    // Attributes
    private static let supportedArchs: [BinaryArchitecture] = BinaryArchitecture.allCases
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - SwiftModuleMetadataProviding
    
    public func loadMetadata(at path: AbsolutePath) throws -> SwiftModuleMetadata {
        let fileName = path.basenameWithoutExt
        let archPattern = SwiftModuleMetadataProvider.supportedArchs.map { $0.rawValue }.sorted { $0.count > $1.count }.joined(separator: "|")
        let arch = try swiftModuleRegexSearch(
            fileName: fileName,
            pattern: "(\(archPattern))"
        )
        let platform = try swiftModuleRegexSearch(
            fileName: fileName,
            pattern: "(\(SwiftModuleMetadata.Platform.allCases.map { $0.rawValue }.joined(separator: "|")))"
        )
        // Platform variant is optinal
        let platformVariant = try swiftModuleRegexSearch(
            fileName: fileName,
            pattern: "(\(SwiftModuleMetadata.PlatformVariant.allCases.map { $0.rawValue}.joined(separator: "|")))"
        )
        guard
            let arch = BinaryArchitecture(rawValue: arch ?? ""),
            let platform = SwiftModuleMetadata.Platform(rawValue: platform ?? "")
        else {
            throw SwiftModuleMetadataProviderError.metadataNotFound(path)
        }
        return SwiftModuleMetadata(
            fileName: fileName + ".swiftmodule",
            arch: arch,
            platform: platform,
            platformVariant: SwiftModuleMetadata.PlatformVariant(rawValue: platformVariant ?? "")
        )
    }
    
    // MARK: - Private
    
    /// Method search by regex pattern inside swift module formated file name
    private func swiftModuleRegexSearch(
        fileName: String,
        pattern: String
    ) throws -> String? {
        let regex = try Regex(pattern)
        guard
            let firstMatch = try regex.firstMatch(in: fileName),
            let output = firstMatch.output.first?.substring
        else {
            return nil
        }
        return String(output)
    }
}
