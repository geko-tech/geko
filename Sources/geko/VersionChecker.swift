import Foundation
import GekoSupport
import struct ProjectDescription.AbsolutePath

private let gekoSourceFileName = "geko_source.json"

private struct GekoSource: Decodable {
    let url: String?
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
        print("Current geko version \(Constants.version) does not match required version \(neededVersion). Please install required version manually or add geko_source.json file to geko bundle to enable auto update")
        exit(1)
    }

    try await downloadVersion(version: neededVersion, url: sourceUrl, cacheDir: versionCacheDir)

    try startOtherVersion(versionDir: versionCacheDir, version: neededVersion)
}

private func downloadVersion(version: String, url: String, cacheDir: AbsolutePath) async throws {
    let client = FileClient()
    let handler: FileHandling = FileHandler.shared

    guard let url = URL(string: url) else {
        exit(1)
    }

    let archive: AbsolutePath
    do {
        print("Downloading geko version \(version)")
        archive = try await client.download(url: url)
    } catch FileClientError.notFoundError, FileClientError.forbiddenError {
        print("Unable to find geko version \(version) at url \(url)")
        fflush(stdout)
        exit(1)
    }

    let unarchiver = try FileUnarchiver(path: archive)
    let unarchivedPath = try unarchiver.unarchive()

    try handler.delete(archive)

    try handler.createFolder(cacheDir.parentDirectory)
    try handler.move(from: unarchivedPath, to: cacheDir)
}

func loadGekoSourceUrl(version: String) throws -> String? {
    guard
        let bundleDir = Bundle(for: FileHandler.self).resourceURL,
        let bundlePath = try? AbsolutePath(validatingAbsolutePath: bundleDir.path(percentEncoded: false))
    else {
        fatalError("Cannot retrieve executable path")
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
        print("Error while loading \(gekoSourceFileName): \(error.localizedDescription)\nAuto-update is disabled")
        return nil
    }

    guard let sourceTemplateUrl = source?.url else {
        print("Source url is not specified in file 'geko_source.json'. Update is disabled.")
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
        fatalError("Unable to exec process! Failed with errno \(errno)")
    }
}

private func versionCacheDirectory(_ version: String) throws -> AbsolutePath {
    let userCacheDir = Environment.shared.versionsDirectory
    return userCacheDir.appending(component: version)
}
