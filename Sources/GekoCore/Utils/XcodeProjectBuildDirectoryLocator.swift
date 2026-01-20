import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol XcodeProjectBuildDirectoryLocating {
    /// Locates the build output directory for `xcodebuild` command.
    ///
    /// For example: `~/Library/Developer/Xcode/DerivedData/PROJECT_NAME/Build/Products/CONFIG_NAME`
    ///
    /// - Parameters:
    ///   - platform: The platform for the built scheme.
    ///   - projectPath: The path of the Xcode project or workspace.
    ///   - derivedDataPath: The path of the derived data
    ///   - configuration: The configuration name, i.e. `Release`, `Debug`, or something custom.
    func locate(
        platform: Platform,
        projectPath: AbsolutePath,
        derivedDataPath: AbsolutePath?,
        configuration: String,
        destination: CacheFrameworkDestination
    ) throws -> AbsolutePath
    
    /// Locates build directory inside Index.noindex folder
    ///
    /// For example: `~/Library/Developer/Xcode/DerivedData/PROJECT_NAME/Index.noindex/Build/Products/CONFIG_NAME`
    ///
    /// - Parameters:
    ///   - platform: The platform for the built scheme.
    ///   - projectPath: The path of the Xcode project or workspace.
    ///   - derivedDataPath: The path of the derived data
    ///   - configuration: The configuration name, i.e. `Release`, `Debug`, or something custom.
    func locateNoIndex(
        platform: Platform,
        projectPath: AbsolutePath,
        derivedDataPath: AbsolutePath?,
        configuration: String,
        destination: CacheFrameworkDestination
    ) throws -> AbsolutePath
}

public final class XcodeProjectBuildDirectoryLocator: XcodeProjectBuildDirectoryLocating {
    private let derivedDataLocator: DerivedDataLocating

    public init(derivedDataLocator: DerivedDataLocating = DerivedDataLocator()) {
        self.derivedDataLocator = derivedDataLocator
    }

    public func locate(
        platform: Platform,
        projectPath: AbsolutePath,
        derivedDataPath: AbsolutePath?,
        configuration: String,
        destination: CacheFrameworkDestination
    ) throws -> AbsolutePath {
        let configSDKPathComponent: String = {
            guard platform != .macOS else {
                return configuration
            }
            let destinationTarget: String
            switch destination {
            case .simulator:
                destinationTarget = platform.xcodeSimulatorSDK!
            case .device:
                destinationTarget = platform.xcodeDeviceSDK
            }
            
            return "\(configuration)-\(destinationTarget)"
        }()
        let derivedDataPath = try derivedDataPath ?? derivedDataLocator.locate(
            for: projectPath
        )
        return derivedDataPath
            .appending(component: "Build")
            .appending(component: "Products")
            .appending(component: configSDKPathComponent)
    }
    
    public func locateNoIndex(
        platform: Platform,
        projectPath: AbsolutePath,
        derivedDataPath: AbsolutePath?,
        configuration: String,
        destination: CacheFrameworkDestination
    ) throws -> AbsolutePath {
        let configSDKPathComponent: String = {
            guard platform != .macOS else {
                return configuration
            }
            let destinationTarget: String
            switch destination {
            case .simulator:
                destinationTarget = platform.xcodeSimulatorSDK!
            case .device:
                destinationTarget = platform.xcodeDeviceSDK
            }
            
            return "\(configuration)-\(destinationTarget)"
        }()
        let derivedDataPath = try derivedDataPath ?? derivedDataLocator.locate(
            for: projectPath
        )
        return derivedDataPath
            .appending(component: "Index.noindex")
            .appending(component: "Build")
            .appending(component: "Products")
            .appending(component: configSDKPathComponent)
    }
    
}
