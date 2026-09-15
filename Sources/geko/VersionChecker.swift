import Foundation
import GekoSupport
import struct ProjectDescription.AbsolutePath

private let gekoSourceFileName = "geko_source.json"
private let logger = Logger(label: "io.geko.version-checker")

private struct GekoSource: Decodable {
    let url: String?
}

private enum VersionCheckerError: FatalError {
    case sourceNotConfigured(current: String, required: String)
    case invalidSourceURL(String)
    case downloadUnavailable(version: String, url: String)
    case missingBundleResources
    case executionFailed(path: String, code: Int32)

    var description: String {
        switch self {
        case let .sourceNotConfigured(current, required):
            return "Current geko version \(current) does not match required version \(required). Please install the required version manually or add geko_source.json to the geko bundle to enable auto-update."
        case let .invalidSourceURL(url):
            return "The geko source URL is invalid: \(url)"
        case let .downloadUnavailable(version, url):
            return "Unable to find geko version \(version) at URL \(url)"
        case .missingBundleResources:
            return "Cannot retrieve the geko bundle resource path."
        case let .executionFailed(path, code):
            return "Unable to execute geko at \(path). execv failed with errno \(code)."
        }
    }

    var type: ErrorType {
        switch self {
        case .sourceNotConfigured, .invalidSourceURL, .downloadUnavailable:
            return .abortSilent
        case .missingBundleResources, .executionFailed:
            return .bug
        }
    }
}

private func getMachineArchitecture() -> String {
    #if arch(arm64)
        return "arm64"
    #elseif arch(arm)
        return "arm"
    #elseif arch(x86_64)
        return "x86_64"
    #elseif arch(i386)
        return "i386"
    #elseif arch(wasm32)
        return "wasm32"
    #else
    #error("Unsupported architecture")
    #endif
}

private func getMachinePlatform() -> String {
    #if os(macOS)
    return "macos"
    #elseif os(Linux)
    return "linux"
    #else
    #error("Unsupported platform")
    #endif
}

func startCorrectVersion() async throws {
    if CommandLine.topLevelArguments.contains("--force") {
        return
    }

    let handler = FileHandler.shared

    let versionFile = AbsolutePath.current.appending(component: Constants.versionFileName)
    guard handler.exists(versionFile) else { return }

    let neededVersion = try handler.readTextFile(versionFile).trimmingCharacters(in: .whitespacesAndNewlines)

    if neededVersion == Constants.version {
        return
    }

    let versionCacheDir = try versionCacheDirectory(neededVersion)
    if handler.isFolder(versionCacheDir) {
        try startOtherVersion(versionDir: versionCacheDir, version: neededVersion)
    }
    try handler.delete(versionCacheDir)

    guard let sourceUrl = try loadGekoSourceUrl(version: neededVersion) else {
        let error = VersionCheckerError.sourceNotConfigured(
            current: Constants.version,
            required: neededVersion
        )
        logger.info("\(error.description)")
        throw error
    }

    try await downloadVersion(version: neededVersion, url: sourceUrl, cacheDir: versionCacheDir)

    try startOtherVersion(versionDir: versionCacheDir, version: neededVersion)
}

private func downloadVersion(version: String, url: String, cacheDir: AbsolutePath) async throws {
    let client = FileClient()
    let handler: FileHandling = FileHandler.shared

    guard let url = URL(string: url) else {
        throw VersionCheckerError.invalidSourceURL(url)
    }

    let archive: AbsolutePath
    do {
        logger.notice("Downloading geko version \(version)")
        archive = try await client.download(url: url)
    } catch FileClientError.notFoundError, FileClientError.forbiddenError {
        let error = VersionCheckerError.downloadUnavailable(version: version, url: url.absoluteString)
        logger.info("\(error.description)")
        throw error
    }

    let unarchiver = try FileUnarchiver(path: archive)
    let unarchivedPath = try unarchiver.unarchive()

    try handler.delete(archive)

    try handler.createFolder(cacheDir.parentDirectory)
    try handler.move(from: unarchivedPath, to: cacheDir)
}

func loadGekoSourceUrl(version: String) throws -> String? {
#if os(macOS)
    let bundle = Bundle(for: FileHandler.self)
#elseif os(Linux)
    let bundle = Bundle.main
#else
    #error("Unsupported architecture")
#endif

    guard
        let bundleDir = bundle.resourceURL,
        let bundlePath = try? AbsolutePath(validatingAbsolutePath: bundleDir.path(percentEncoded: false))
    else {
        throw VersionCheckerError.missingBundleResources
    }

    let gekoSourcePath = bundlePath.appending(component: gekoSourceFileName)

    guard FileHandler.shared.exists(gekoSourcePath) else {
        return nil
    }

    let data = try FileHandler.shared.readFile(gekoSourcePath)
    let jsonDecoder = JSONDecoder()
    var source: GekoSource? = nil
    do {
        source = try jsonDecoder.decode(GekoSource.self, from: data)
    } catch {
        logger.warning("Error while loading \(gekoSourceFileName): \(error.localizedDescription). Auto-update is disabled.")
        return nil
    }

    guard let sourceTemplateUrl = source?.url else {
        logger.warning("Source URL is not specified in '\(gekoSourceFileName)'. Auto-update is disabled.")
        return nil
    }

    let sourceUrl = sourceTemplateUrl
        .replacingOccurrences(of: "{platform}", with: getMachinePlatform())
        .replacingOccurrences(of: "{arch}", with: getMachineArchitecture())
        .replacingOccurrences(of: "{version}", with: version)

    return sourceUrl
}

private func startOtherVersion(versionDir: AbsolutePath, version: String) throws {
    var arguments = CommandLine.arguments
    if version >= Constants.execSupportMinVersion {
        assert(arguments.count > 0)

        // to avoid potential infinite loop, add --force flag after first argument,
        // which is path to or name of executable
        arguments.insert("--force", at: 1)
    }

    // unblock signals for next process
    var sigs: sigset_t = .init()
    sigfillset(&sigs)
    sigprocmask(SIG_UNBLOCK, &sigs, nil)

    let path = versionDir.appending(component: Constants.binName).pathString
    let cArgs = CStringArray(arguments)
    guard execv(path, cArgs.cArray) != -1 else {
        throw VersionCheckerError.executionFailed(path: path, code: errno)
    }
}

private func versionCacheDirectory(_ version: String) throws -> AbsolutePath {
    let userCacheDir = Environment.shared.versionsDirectory
    return userCacheDir.appending(component: version)
}
