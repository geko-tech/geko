import Foundation
import struct ProjectDescription.AbsolutePath

/// Project Description Paths
///
/// A small utility that works out the various search paths needed
/// for a given `ProjectDescription` library.
public struct ProjectDescriptionSearchPaths {
    enum Style {
        /// `libProjectDescription.dylib` library built via Swift PM in the command line
        ///
        /// `swift build`
        ///
        /// Example:
        /// /path/to/geko/.build/$CONFIGURATION/libProjectDescription.dylib
        case commandLine

        /// `ProjectDescription.framework` framework built via Xcode
        ///
        /// `swift package generate-xcodeproj`
        ///
        /// Example:
        /// /path/to/DerivedData/Geko/Build/Products/$CONFIGURATION/ProjectDescription.framework
        case xcode

        /// `ProjectDescription.framework` framework built via Swift Packages in Xcode
        ///
        /// `open Package.swift`
        ///
        ///  - Note: The `.framework` resides within `$BUILT_PRODUCTS_DIR/PackageFrameworks`, however
        ///  the `.swiftmodule` remains within `$BUILT_PRODUCTS_DIR`.
        ///
        /// Example:
        /// /path/to/DerivedData/Geko/Build/Products/$CONFIGURATION/PackageFrameworks/ProjectDescription.framework
        case swiftPackageInXcode
    }

    /// Path to the `ProjectDescription` framework or library
    var path: AbsolutePath

    /// The search path style to use for the library
    var style: Style

    public var includeSearchPath: AbsolutePath {
        switch style {
        case .commandLine:
            #if compiler(>=6.0.0)
                return path.parentDirectory.appending(component: "Modules")
            #else
                return path.parentDirectory
            #endif
        case .xcode:
            return path.parentDirectory
        case .swiftPackageInXcode:
            return path.parentDirectory.parentDirectory
        }
    }

    public var librarySearchPath: AbsolutePath {
        switch style {
        case .commandLine:
            return path.parentDirectory
        case .xcode:
            return path.parentDirectory
        case .swiftPackageInXcode:
            return path.parentDirectory.parentDirectory
        }
    }

    public var frameworkSearchPath: AbsolutePath {
        switch style {
        case .commandLine:
            return path.parentDirectory
        case .xcode:
            return path.parentDirectory
        case .swiftPackageInXcode:
            return path.parentDirectory
        }
    }

    /// Creates the `ProjectDescription` search paths based on the library path specified
    public static func paths(for libraryPath: AbsolutePath) -> ProjectDescriptionSearchPaths {
        ProjectDescriptionSearchPaths(
            path: libraryPath,
            style: pathStyle(for: libraryPath)
        )
    }

    private static func pathStyle(for libraryPath: AbsolutePath) -> ProjectDescriptionSearchPaths.Style {
        if libraryPath.extension == "framework" {
            if libraryPath.parentDirectory.components.last == "PackageFrameworks" {
                return .swiftPackageInXcode
            }
            return .xcode
        }
        return .commandLine
    }
}
