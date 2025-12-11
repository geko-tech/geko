import Foundation

public final class SymlinksFinder {
    
    public init() {}

    public func findSymlinks(in directory: URL) -> [String: String] {
        var symlinksDictionary: [String: String] = [:]
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey]) else {
            logger.warning("Couldn't get the contents of the directory \(directory.path)")
            return symlinksDictionary
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isSymbolicLinkKey])
                if resourceValues.isSymbolicLink == true {
                    let destinationPath = try fileManager.destinationOfSymbolicLink(atPath: fileURL.path)
                    let directoryPath = directory.absoluteString.hasSuffix("/") ? directory.absoluteString : directory.absoluteString + "/"
                    var targetPath = URL(fileURLWithPath: destinationPath, relativeTo: fileURL.deletingLastPathComponent())
                        .absoluteString.replacingOccurrences(of: directoryPath, with: "")
                    if targetPath.hasSuffix("/") {
                        targetPath.removeLast()
                    }
                    var linkPath = fileURL.absoluteString.replacingOccurrences(of: directoryPath, with: "")
                    if linkPath.hasSuffix("/") {
                        linkPath.removeLast()
                    }
                    symlinksDictionary[linkPath] = targetPath
                }
            } catch {
                logger.warning("Processing error \(fileURL.path): \(error)")
            }
        }

        return symlinksDictionary
    }
}

