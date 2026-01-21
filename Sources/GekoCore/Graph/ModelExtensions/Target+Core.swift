import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

public enum TargetError: FatalError, Equatable {
    case invalidSourcesGlob(targetName: String, invalidGlobs: [InvalidGlob])

    public var type: ErrorType { .abort }

    public var description: String {
        switch self {
        case let .invalidSourcesGlob(targetName: targetName, invalidGlobs: invalidGlobs):
            return "The target \(targetName) has the following invalid source files globs:\n" + invalidGlobs
                .invalidGlobsDescription
        }
    }
}

extension Target {
    /// Returns the product name including the extension.
    public var productNameWithExtension: String {
        switch product {
        case .staticLibrary, .dynamicLibrary:
            return "lib\(productName).\(product.xcodeValue.fileExtension!)"
        case .commandLineTool:
            return productName
        case _:
            if let fileExtension = product.xcodeValue.fileExtension {
                return "\(productName).\(fileExtension)"
            } else {
                return productName
            }
        }
    }

    /// Returns true if the file at the given path is a resource.
    /// - Parameter path: Path to the file to be checked.
    public static func isResource(path: AbsolutePath) -> Bool {
        if path.isPackage {
            return true
        } else if !FileHandler.shared.isFolder(path) {
            return true
            // We filter out folders that are not Xcode supported bundles such as .app or .framework.
        } else if let `extension` = path.extension, Target.validFolderExtensions.contains(`extension`) {
            return true
        } else {
            return false
        }
    }
}
