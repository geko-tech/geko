import Foundation
import ProjectDescription

public protocol DeveloperEnvironmenting {
    /// Returns the derived data directory selected in the environment.
    func derivedDataDirectory(for workspacePath: AbsolutePath) throws -> DerivedDataPath

    /// Returns the system's architecture.
    var architecture: MacArchitecture { get }
}

public enum DerivedDataPath {
    case `default`(path: AbsolutePath)
    case relative(path: AbsolutePath)
    case custom(path: AbsolutePath)
}

public final class DeveloperEnvironment: DeveloperEnvironmenting {
    /// Shared instance to be used publicly.
    /// Since the environment doesn't change during the execution of Geko, we can cache
    /// state internally to speed up future access to environment attributes.
    public internal(set) static var shared: DeveloperEnvironmenting = DeveloperEnvironment()

    /// File handler instance.
    let fileHandler: FileHandling

    convenience init() {
        self.init(fileHandler: FileHandler())
    }

    private init(fileHandler: FileHandling) {
        self.fileHandler = fileHandler
    }

    // swiftlint:disable identifier_name

    /// https://pewpewthespells.com/blog/xcode_build_locations.html
    @Atomic private var _derivedDataDirectory: DerivedDataPath?
    public func derivedDataDirectory(for workspacePath: AbsolutePath) throws -> DerivedDataPath {
        if let _derivedDataDirectory {
            return _derivedDataDirectory
        }
        let location: DerivedDataPath
        
        if let workspaceSettingDerivedPath = try workspaceSettingsDerivedDataPath(workspacePath: workspacePath) {
            location = workspaceSettingDerivedPath
        } else if let customLocation = try? System.shared.runShell([
            "/usr/bin/defaults",
            "read",
            "com.apple.dt.Xcode IDECustomDerivedDataLocation",
        ]) {
            let customLocationPath = try AbsolutePath(validating: customLocation.chomp())
            if customLocationPath.isAbsolute {
                location = .custom(path: customLocationPath)
            } else {
                location = .relative(path: AbsolutePath(stringLiteral: workspacePath.dirname).appending(customLocationPath))
            }
        } else {
            // Default location
            // swiftlint:disable:next force_try
            location = .default(path: fileHandler.homeDirectory.appending(try! RelativePath(validating: "Library/Developer/Xcode/DerivedData/")))
        }
        _derivedDataDirectory = location
        return location
    }

    @Atomic private var _architecture: MacArchitecture?
    public var architecture: MacArchitecture {
        if let _architecture {
            return _architecture
        }
        // swiftlint:disable:next force_try
        let output = try! System.shared.capture(["/usr/bin/uname", "-m"]).chomp()
        _architecture = MacArchitecture(rawValue: output)
        return _architecture!
    } // swiftlint:enable identifier_name

    // MARK: - Private

    private func workspaceSettingsDerivedDataPath(
        workspacePath: AbsolutePath
    ) throws -> DerivedDataPath? {
        guard let workspaceSettingsPath = try FileHandler.shared.glob(workspacePath, patterns: ["xcuserdata/**/WorkspaceSettings.xcsettings"], exclude: []).first else {
            return nil
        }
        let settings: XCWorkspaceSettingsPlist = try FileHandler.shared.readPlistFile(workspaceSettingsPath)
        switch settings.derivedDataLocationStyle {
        case .default:
            // If workspace settings select default location we should check global settings
            return nil
        case .workspaceRelativePath:
            guard let customLocation = settings.derivedDataCustomLocation else { return nil }
            // In case relative derived data location we need absolute path
            return .relative(path: AbsolutePath(stringLiteral: workspacePath.dirname).appending(component: customLocation.chomp()))
        case .absolutePath:
            guard let customLocation = settings.derivedDataCustomLocation else { return nil }
            return .custom(path: try AbsolutePath(validatingAbsolutePath: customLocation.chomp()))
        }
    }
}
