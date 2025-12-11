import Foundation
import struct ProjectDescription.AbsolutePath

public protocol FileContentHashing {
    func hash(path: AbsolutePath) throws -> String
    func hash(path filePath: AbsolutePath, exclude: [(AbsolutePath) -> Bool]) throws -> String
}
