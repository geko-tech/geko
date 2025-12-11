import Foundation
import PathKit
import struct ProjectDescription.AbsolutePath

extension AbsolutePath {
    var path: Path {
        Path(pathString)
    }
}
