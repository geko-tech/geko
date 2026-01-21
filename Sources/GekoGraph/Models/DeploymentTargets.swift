import Foundation
import ProjectDescription

// MARK: - DeploymentTargets

extension DeploymentTargets {
    public var configuredVersions: [(platform: Platform, versionString: String)] {
        var versions = [(Platform, String)]()

        if let iOS {
            versions.append((.iOS, iOS))
        }

        if let macOS {
            versions.append((.macOS, macOS))
        }

        if let watchOS {
            versions.append((.watchOS, watchOS))
        }

        if let tvOS {
            versions.append((.tvOS, tvOS))
        }

        if let visionOS {
            versions.append((.visionOS, visionOS))
        }

        return versions
    }
}
