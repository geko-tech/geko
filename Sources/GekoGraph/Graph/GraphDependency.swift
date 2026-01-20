import Foundation
import ProjectDescription

public enum GraphDependency: Hashable, CustomStringConvertible, Comparable, Codable {
    public struct XCFramework: Hashable, CustomStringConvertible, Comparable, Codable {
        public let path: AbsolutePath
        public let infoPlist: XCFrameworkInfoPlist
        public let primaryBinaryPath: AbsolutePath
        public let linking: BinaryLinking
        public let mergeable: Bool
        public let status: LinkingStatus

        public init(
            path: AbsolutePath,
            infoPlist: XCFrameworkInfoPlist,
            primaryBinaryPath: AbsolutePath,
            linking: BinaryLinking,
            mergeable: Bool,
            status: LinkingStatus,
            macroPath _: AbsolutePath?
        ) {
            self.path = path
            self.infoPlist = infoPlist
            self.primaryBinaryPath = primaryBinaryPath
            self.linking = linking
            self.mergeable = mergeable
            self.status = status
        }

        public var description: String {
            "xcframework '\(path.basename)'"
        }

        public static func < (lhs: GraphDependency.XCFramework, rhs: GraphDependency.XCFramework) -> Bool {
            lhs.description < rhs.description
        }
    }

    public enum PackageProductType: String, Hashable, CustomStringConvertible, Comparable, Codable {
        public var description: String {
            rawValue
        }

        case runtime = "runtime package product"
        case plugin = "plugin package product"
        case macro = "macro package product"

        public static func < (lhs: PackageProductType, rhs: PackageProductType) -> Bool {
            lhs.description < rhs.description
        }
    }

    case xcframework(GraphDependency.XCFramework)

    /// A dependency that represents a pre-compiled framework.
    case framework(
        path: AbsolutePath,
        binaryPath: AbsolutePath,
        dsymPath: AbsolutePath?,
        bcsymbolmapPaths: [AbsolutePath],
        linking: BinaryLinking,
        architectures: [BinaryArchitecture],
        status: LinkingStatus
    )

    /// A dependency that represents a pre-compiled library.
    case library(
        path: AbsolutePath,
        publicHeaders: AbsolutePath,
        linking: BinaryLinking,
        architectures: [BinaryArchitecture],
        swiftModuleMap: AbsolutePath?
    )

    /// A macOS executable that represents a macro
    case macro(path: AbsolutePath)

    /// A dependency that represents a pre-compiled bundle.
    case bundle(path: AbsolutePath)

    /// A dependency that represents a target that is defined in the project at the given path.
    case target(name: String, path: AbsolutePath, status: LinkingStatus = .required)

    /// A dependency that represents an SDK
    case sdk(name: String, path: AbsolutePath, status: LinkingStatus, source: SDKSource)

    public func hash(into hasher: inout Hasher) {
        switch self {
        case let .macro(path):
            hasher.combine(path)
        case let .xcframework(xcframework):
            hasher.combine("xcframework")
            hasher.combine(xcframework.path)
        case let .framework(path, _, _, _, linking, _, _):
            hasher.combine("framework")
            hasher.combine(path)
            hasher.combine(linking)
        case let .library(path, _, _, _, _):
            hasher.combine("library")
            hasher.combine(path)
        case let .bundle(path):
            hasher.combine("bundle")
            hasher.combine(path)
        case let .target(name, path, _):
            hasher.combine("target")
            hasher.combine(name)
            hasher.combine(path)
        case let .sdk(name, path, status, source):
            hasher.combine("sdk")
            hasher.combine(name)
            hasher.combine(path)
            hasher.combine(status)
            hasher.combine(source)
        }
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.macro(lhsPath), .macro(rhsPath)):
            return lhsPath == rhsPath
        case let (.xcframework(lhs), .xcframework(rhs)):
            return lhs.path == rhs.path
        case let (.framework(lhsPath, _, _, _, lhsLinking, _, _), .framework(rhsPath, _, _, _, rhsLinking, _, _)):
            return lhsPath == rhsPath && lhsLinking == rhsLinking
        case let (.library(lhsPath, _, _, _, _), .library(rhsPath, _, _, _, _)):
            return lhsPath == rhsPath
        case let (.bundle(lhsPath), .bundle(rhsPath)):
            return lhsPath == rhsPath
        case let (.target(lhsName, lhsPath, _), .target(rhsName, rhsPath, _)):
            return lhsName == rhsName && lhsPath == rhsPath
        case let (.sdk(lhsName, lhsPath, lhsStatus, lhsSource), .sdk(rhsName, rhsPath, rhsStatus, rhsSource)):
            return lhsName == rhsName
                && lhsPath == rhsPath
                && lhsStatus == rhsStatus
                && lhsSource == rhsSource
        default:
            return false
        }
    }

    public var isTarget: Bool {
        switch self {
        case .macro: return false
        case .xcframework: return false
        case .framework: return false
        case .library: return false
        case .bundle: return false
        case .target: return true
        case .sdk: return false
        }
    }

    public var isSdk: Bool {
        guard case .sdk = self else {
            return false
        }
        return true
    }

    /**
     When the graph dependency represents a pre-compiled static binary.
     */
    public var isStaticPrecompiled: Bool {
        switch self {
        case .macro: return false
        case let .xcframework(xcframework):
            return xcframework.linking == .static
        case let .framework(_, _, _, _, linking, _, _),
            let .library(_, _, linking, _, _):
            return linking == .static
        case .bundle: return false
        case .target: return false
        case .sdk: return false
        }
    }

    /**
     When the graph dependency represents a dynamic precompiled binary, it returns true.
     */
    public var isDynamicPrecompiled: Bool {
        switch self {
        case .macro: return false
        case let .xcframework(xcframework):
            return xcframework.linking == .dynamic
        case let .framework(_, _, _, _, linking, _, _),
            let .library(_, _, linking, _, _):
            return linking == .dynamic
        case .bundle: return false
        case .target: return false
        case .sdk: return false
        }
    }

    public var isPrecompiled: Bool {
        switch self {
        case .macro: return true
        case .xcframework: return true
        case .framework: return true
        case .library: return true
        case .bundle: return true
        case .target: return false
        case .sdk: return false
        }
    }

    public var isLinkable: Bool {
        switch self {
        case .macro: return false
        case .xcframework: return true
        case .framework: return true
        case .library: return true
        case .bundle: return false
        case .target: return true
        case .sdk: return true
        }
    }

    public var isPrecompiledMacro: Bool {
        switch self {
        case .macro: return true
        case .xcframework: return false
        case .framework: return false
        case .library: return false
        case .bundle: return false
        case .target: return false
        case .sdk: return false
        }
    }

    public var isPrecompiledDynamicAndLinkable: Bool {
        switch self {
        case .macro: return false
        case let .xcframework(xcframework):
            return xcframework.linking == .dynamic
        case let .framework(_, _, _, _, linking, _, _),
            let .library(path: _, publicHeaders: _, linking: linking, architectures: _, swiftModuleMap: _):
            return linking == .dynamic
        case .bundle: return false
        case .target: return false
        case .sdk: return false
        }
    }

    // MARK: - Internal

    public var targetDependency: (name: String, path: AbsolutePath)? {
        switch self {
        case let .target(name: name, path: path, _):
            return (name, path)
        default:
            return nil
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .macro:
            return "macro '\(name)'"
        case .xcframework:
            return "xcframework '\(name)'"
        case .framework:
            return "framework '\(name)'"
        case .library:
            return "library '\(name)'"
        case .bundle:
            return "bundle '\(name)'"
        case .target:
            return "target '\(name)'"
        case .sdk:
            return "sdk '\(name)'"
        }
    }

    public var name: String {
        switch self {
        case let .macro(path):
            return path.basename
        case let .xcframework(xcframework):
            return xcframework.path.basename
        case let .framework(path, _, _, _, _, _, _):
            return path.basename
        case let .library(path, _, _, _, _):
            return path.basename
        case let .bundle(path):
            return path.basename
        case let .target(name, _, _):
            return name
        case let .sdk(name, _, _, _):
            return name
        }
    }

    public var nameWithoutExtension: String {
        switch self {
        case let .macro(path):
            return path.basenameWithoutExt
        case let .xcframework(xcframework):
            return xcframework.path.basenameWithoutExt
        case let .framework(path, _, _, _, _, _, _):
            return path.basenameWithoutExt
        case let .library(path, _, _, _, _):
            return path.basenameWithoutExt
        case let .bundle(path):
            return path.basenameWithoutExt
        case let .target(name, _, _):
            return name
        case let .sdk(name, _, _, _):
            return name
        }
    }

    // MARK: - Comparable

    public static func < (lhs: GraphDependency, rhs: GraphDependency) -> Bool {
        lhs.description < rhs.description
    }
}
