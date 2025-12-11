import Foundation
#if os(Linux)
import CoreFoundation
#endif

extension FileManager {
    static func subdirectoriesResolvingSymbolicLinks(atPath path: String) -> [String] {
        return enumerate(atPath: path, includeFiles: false)
    }

    static func filesAndDirectories(atPath path: String) -> [String] {
        return enumerate(atPath: path, includeFiles: true)
    }

    // traverses file tree and returns each file and directory, following symlinks
    private static func enumerate(atPath path: String, includeFiles: Bool) -> [String] {
        var result: [String] = []

        let unsafeStringCopy = path.unsafeUTF8Copy()
        defer { unsafeStringCopy.deallocate() }

        let arrayPointer: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> = .allocate(capacity: 2)
        defer { arrayPointer.deallocate() }
        arrayPointer[0] = unsafeStringCopy.baseAddress
        arrayPointer[1] = nil

        let fileSystem = fts_open(arrayPointer, FTS_COMFOLLOW | FTS_NOCHDIR, nil)
        guard let fileSystem else { return result }
        defer { fts_close(fileSystem) }

        while let fileEntry = fts_read(fileSystem) {
            let info = fileEntry[0].fts_info

            if info == FTS_D || (includeFiles && info == FTS_F) {
                let string = String(cString: fileEntry[0].fts_path)
                result.append(string)
            } else if info == FTS_SL {
                // follow symlink
                fts_set(fileSystem, fileEntry, FTS_FOLLOW)
            }
        }

        return result
    }

    func isDirectory(path: String) -> Bool {
        var isDirectoryBool = ObjCBool(false)
        let doesFileExist = fileExists(atPath: path, isDirectory: &isDirectoryBool)
        return doesFileExist && isDirectoryBool.boolValue
    }
}

extension String {
    /// Create UnsafeMutableBufferPointer holding a null-terminated UTF8 copy of the string
    fileprivate func unsafeUTF8Copy() -> UnsafeMutableBufferPointer<CChar> {
        let utf8CString = self.utf8CString
        let copy = UnsafeMutableBufferPointer<CChar>.allocate(capacity: utf8CString.underestimatedCount)
        _ = copy.initialize(from: utf8CString)
        return copy
    }
}
