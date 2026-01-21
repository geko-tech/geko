import Foundation
import ProjectDescription

extension CompatibleXcodeVersions {
    public func isCompatible(versionString: String) -> Bool {
        let xCodeVersion: Version = "\(versionString)"

        switch self {
        case .all:
            return true
        case let .exact(version):
            return version == xCodeVersion
        case let .upToNextMajor(version):
            return xCodeVersion.major == version.major && xCodeVersion >= version
        case let .upToNextMinor(version):
            return version.major == xCodeVersion.major && version.minor == xCodeVersion.minor && xCodeVersion >= version
        case let .list(versions):
            return versions.contains { $0.isCompatible(versionString: versionString) }
        }
    }
}
