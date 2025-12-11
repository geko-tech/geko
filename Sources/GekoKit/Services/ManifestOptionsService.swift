import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport

enum ManifestOptionsServiceError: FatalError {
    case invalidProfileName(String)

    public var description: String {
        switch self {
        case let .invalidProfileName(profileName):
            return "Profile with name \"\(profileName)\" was not found in \(Constants.projectProfilesFileName)"
        }
    }

    var type: GekoSupport.ErrorType {
        return .abort
    }
}

final class ManifestOptionsService {
    func load(options: ManifestOptions, path: String?) throws {
        try load(profileName: options.projectProfile, path: path)
        load(flags: options.flags)
    }
}

// MARK: - Flags

extension ManifestOptionsService {
    fileprivate func load(flags: [String]) {
        for flag in flags {
            let env = "GEKO_MANIFEST_FLAG_\(flag)"
            setenv(env, "true", 1)
        }
    }
}

// MARK: - Profiles

extension ManifestOptionsService {
    fileprivate func load(profileName: String?, path: String?) throws {
        let path = try self.path(path)

        let profilesFilePath =
            path
            .appending(component: Constants.gekoDirectoryName)
            .appending(component: Constants.projectProfilesFileName)

        guard FileHandler.shared.exists(profilesFilePath) else { return }

        let data = try FileHandler.shared.readFile(profilesFilePath)
        let profiles: [String: [String: String]] = try parseYaml(data, context: .file(path: profilesFilePath))

        let values: [String: String]
        if let profileName {
            guard let profileValues = profiles[profileName] else {
                throw ManifestOptionsServiceError.invalidProfileName(profileName)
            }
            values = profileValues
            logger.info("Loaded profile \(profileName)", metadata: .subsection)
        } else {
            guard let defaultProfile = profiles["default"] else {
                return
            }
            values = defaultProfile
            logger.info("Loaded default profile", metadata: .subsection)
        }

        for (key, value) in values {
            setenv(key, value, 0)
        }
    }

    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath)
        } else {
            return FileHandler.shared.currentPath
        }
    }
}
