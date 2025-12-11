import Foundation
import struct ProjectDescription.AbsolutePath
import GekoSupport

final class VersionService {
    func geko() throws {
        logger.notice("\(Constants.version)")
    }
    
    func projectDescription() throws {
        logger.notice("\(Constants.projectDescriptionVersion)")
    }
}
