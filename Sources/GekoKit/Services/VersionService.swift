import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport

final class VersionService {
    func geko() throws {
        let version = Constants.version
        CommandOutputStore.shared.set(.gekoVersion, value: version)
        logger.notice("\(version)")
    }
    
    func projectDescription() throws {
        let version = Constants.projectDescriptionVersion
        CommandOutputStore.shared.set(.projectDescriptionVersion, value: version)
        logger.notice("\(version)")
    }
}
