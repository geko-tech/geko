import Foundation
import TSCBasic
import AppKit

protocol IUpdateAppService: AnyObject {
    func lastAvailableVersion() throws -> String
    func allVersions() throws -> [String]
    func updateApp(version: String) throws
    func needUpdate() throws -> NeedUpdateStatus
}

enum NeedUpdateStatus {
    case updateRequired(Version)
    case updateNotRequired
}

enum UpdateAppError: FatalError {
    case createDirError(error: Error)
    case s3DownloadError(error: Error, version: String)
    case wrongPath(path: String)
    case unzipError(error: Error)
    case noBundleForNameError(name: String)
    case executableFileNotFound(bundlePath: String)

    var errorDescription: String? {
        switch self {
        case .createDirError(let error):
            "Create tmp dir error \(error.localizedDescription)"
        case .s3DownloadError(let error, let version):
            "Download from S3 \(version) error \(error.localizedDescription)"
        case .wrongPath(let path):
            "Wrong path \(path)"
        case .unzipError(let error):
            "Unzip error \(error.localizedDescription)"
        case .noBundleForNameError(let name):
            "No bundle with name \(name) found"
        case .executableFileNotFound(let bundlePath):
            "Exutable file not found \(bundlePath)"
        }
    }

    var type: FatalErrorType {
        .abort
    }
}

enum CompareVersionError: FatalError {
    case noAvailableVersion(Version)
    case invalidVersion(String)

    var errorDescription: String? {
        switch self {
        case .noAvailableVersion(let version):
            "Supported version for Geko \(version.string) not found"
        case .invalidVersion(let version):
            "Version \(version) invalid"
        }
    }

    var type: FatalErrorType {
        .abort
    }
}

final class UpdateAppService: IUpdateAppService {
    // MARK: - Attributes

    private let sessionService: ISessionService
    private var projectPathProvider: IProjectPathProvider
    private let projectsProvider: IProjectsProvider

    // MARK: - Initialization

    init(
        sessionService: ISessionService,
        projectPathProvider: IProjectPathProvider,
        projectsProvider: IProjectsProvider
    ) {
        self.sessionService = sessionService
        self.projectPathProvider = projectPathProvider
        self.projectsProvider = projectsProvider
    }

    func needUpdate() throws -> NeedUpdateStatus {
        guard let path = projectsProvider.selectedProject()?.clearPath() else {
            throw GlobalError.projectNotSelected
        }
        let gekoVersionFilePath = path
            .appending(component: Constants.gekoVersionFile)
        if FileManager.default.fileExists(atPath: gekoVersionFilePath.pathString) {
            let data = try Data(contentsOf: gekoVersionFilePath.asURL)
            guard let rawLocalVersion = String(data: data, encoding: .utf8) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Corrupted geko-version data"))
            }
            let localVersion = try parseVersion(rawLocalVersion.removeNewLines())
            return try compareVersion(localVersion)
        } else {
            let rawGlobalVersion = try sessionService.exec("geko version").removeNewLines()
            let globalVersion = try parseVersion(rawGlobalVersion)
            return try compareVersion(globalVersion)
        }
    }

    private func parseVersion(_ string: String) throws -> Version {
        if string.hasPrefix("geko_stage") {
            var version = string.replacingOccurrences(of: "geko_stage/geko_", with: "").split(separator: "-").first ?? ""
            if let parsedVersion = Version(string: String(version)) {
                return parsedVersion
            } else {
                throw CompareVersionError.invalidVersion(String(version))
            }
        } else {
            if let parsedVersion = Version(string: String(string)) {
                return parsedVersion
            } else {
                throw CompareVersionError.invalidVersion(string)
            }
        }
    }

    private func compareVersion(_ projectVersion: Version) throws -> NeedUpdateStatus {
        guard let appVersion = Version(string: Constants.appVersion) else {
            throw CompareVersionError.invalidVersion(Constants.appVersion)
        }

        if projectVersion.major == appVersion.major, projectVersion.major > 0 {
            return .updateNotRequired
        }

        guard projectVersion.major != appVersion.major || projectVersion.major == appVersion.major && projectVersion.major == 0 else {
            return .updateNotRequired
        }
        guard let lastAvailableVersion = try latestAvailableVersion(for: projectVersion) else {
            throw CompareVersionError.noAvailableVersion(projectVersion)
        }
        return .updateRequired(lastAvailableVersion)
    }

    private func latestAvailableVersion(for version: Version) throws -> Version? {
        let allVersions = try allVersions().compactMap { Version(string: $0) }
        return allVersions
            .filter { $0.major == version.major }
            .filter { $0.minor == version.minor }
            .sorted(by: { $0.patch > $1.patch })
            .first
    }

    // MARK: - Shell

    func lastAvailableVersion() throws -> String {
        switch try sessionService.exec(ShellCommand(arguments: [Constants.versionCommand])) {
        case .collected(let data):
            if let str = String(data: data, encoding: .utf8) {
                return str
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Corrupted data"))
            }
        default:
            throw ResponseTypeError.wrongType
        }
    }

    func allVersions() throws -> [String] {
        switch try sessionService.exec(ShellCommand(arguments: [Constants.versionCommand2])) {
        case .collected(let data):
            if let str = String(data: data, encoding: .utf8) {
                return str.split(separator: "\n").map { String($0) }
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Corrupted data"))
            }
        default:
            throw ResponseTypeError.wrongType
        }
    }

    func updateApp(version: String) throws {
        let tmpdir: URL
        do {
            tmpdir = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: FileManager.default.homeDirectoryForCurrentUser, create: true)
        } catch {
            throw UpdateAppError.createDirError(error: error)
        }

        try download(for: version, path: tmpdir.path())
        try unzip(for: version, path: tmpdir.path())

        guard let downloadedAppBundle = Bundle(url: tmpdir.appendingPathComponent("GekoDesktop.app")) else {
            throw UpdateAppError.noBundleForNameError(name: "GekoDesktop.app")
        }

        let installedAppBundle = Bundle.main

        let installed = AbsolutePath(url: installedAppBundle.bundleURL)
        let downloaded = AbsolutePath(url: downloadedAppBundle.bundleURL)

        try FileManager.default.removeItem(at: installed.asURL)
        try FileManager.default.moveItem(at: downloaded.asURL, to: installed.asURL)
        try FileManager.default.removeItem(at: tmpdir)

        guard let executable = installedAppBundle.executableURL else {
            throw UpdateAppError.noBundleForNameError(name: installedAppBundle.bundlePath)
        }
        let proc = Process()
        proc.executableURL = executable
        proc.launch()

        NSRunningApplication.current.forceTerminate()
    }

    private func download(for version: String, path: String) throws {
        let url = Bundle.main.url(forResource: "source", withExtension: "json")!
        let json = try JSON(string: String(contentsOf: url, encoding: .utf8))

        guard case let .dictionary(dict) = json,
              case var .string(downloadUrl) = dict["utilityUrl"]
        else { throw UpdateAppError.s3DownloadError(error: URLError(.badURL), version: version) }

        downloadUrl = downloadUrl.replacingOccurrences(of: "{version}", with: version)

        var commands: [String] = []
        commands.append("cd \(path)")
        commands.append("curl -L -o \(path)GekoDesktop.app_\(version).zip \(downloadUrl)")

        do {
            try sessionService.exec(ShellCommand(arguments: [commands.joined(separator: " && ")]))
        } catch {
            throw UpdateAppError.s3DownloadError(error: error, version: version)
        }
    }

    private func unzip(for version: String, path: String) throws {
        var commands: [String] = []
        commands.append("cd \(path)")
        commands.append("unzip GekoDesktop.app_\(version).zip")

        do {
            try sessionService.exec(ShellCommand(arguments: [commands.joined(separator: " && ")]))
        } catch {
            throw UpdateAppError.unzipError(error: error)
        }
    }
}
