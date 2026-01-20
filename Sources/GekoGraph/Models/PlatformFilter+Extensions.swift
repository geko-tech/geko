import Foundation
import ProjectDescription

extension PlatformFilter {
    public var xcodeprojValue: String {
        switch self {
        case .catalyst:
            return "maccatalyst"
        case .macos:
            return "macos"
        case .tvos:
            return "tvos"
        case .ios:
            return "ios"
        case .driverkit:
            return "driverkit"
        case .watchos:
            return "watchos"
        case .visionos:
            return "xros"
        }
    }

    /// It returns the platform that the filter is filtering for
    public var platform: Platform? {
        switch self {
        case .ios, .catalyst:
            return .iOS
        case .macos:
            return .macOS
        case .tvos:
            return .tvOS
        case .watchos:
            return .watchOS
        case .visionos:
            return .visionOS
        case .driverkit:
            // TODO: Add support for it
            return nil
        }
    }
}

extension PlatformFilters {
    /// Examples -
    /// This should not be here but downstream
    ///  `platformFilter = ios`
    ///  `platformFilters = (ios, xros, )`
    public var xcodeprojValue: [String] {
        map(\.xcodeprojValue).sorted()
    }
}

extension PlatformFilters: @retroactive Comparable {
    public static func < (lhs: Set<PlatformFilter>, rhs: Set<PlatformFilter>) -> Bool {
        lhs.map(\.xcodeprojValue).sorted().joined() < rhs.map(\.xcodeprojValue).sorted().joined()
    }
}

