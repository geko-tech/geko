import Foundation
import struct ProjectDescription.AbsolutePath
import XcodeProj

protocol FileGenerating: AnyObject {
    func generateFile(
        path: AbsolutePath,
        in group: PBXGroup,
        sourceRootPath: AbsolutePath
    ) throws -> PBXFileReference
}

final class FileGenerator: FileGenerating {
    func generateFile(
        path: AbsolutePath,
        in group: PBXGroup,
        sourceRootPath: AbsolutePath
    ) throws -> PBXFileReference {
        try group.addFile(at: path.path, sourceTree: .group, sourceRoot: sourceRootPath.path)
    }
}
