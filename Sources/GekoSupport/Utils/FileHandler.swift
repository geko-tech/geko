#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

import Crypto
import Foundation
import ProjectDescription
import ZIPFoundation
import SystemPackage
import Glob

#if os(Linux)
import CoreFoundation
#endif

public struct FileStat {
    let isFolder: Bool
}

public enum FileHandlerError: FatalError, Equatable {
    case invalidTextEncoding(AbsolutePath)
    case writingError(AbsolutePath)
    case fileNotFound(AbsolutePath)
    case unreachableFileSize(AbsolutePath)
    case unreachableFileAccessDate(AbsolutePath)
    case expectedAFile(AbsolutePath)
    case nonExistentGlobDirectory(String, AbsolutePath)

    public var description: String {
        switch self {
        case let .invalidTextEncoding(path):
            return "The file at \(path.pathString) is not a utf8 text file"
        case let .writingError(path):
            return "Couldn't write to the file \(path.pathString)"
        case let .fileNotFound(path):
            return "File not found at \(path.pathString)"
        case let .unreachableFileSize(path):
            return "Could not get the file size at path \(path.pathString)"
        case let .unreachableFileAccessDate(path):
            return "Could not get the file access date at path \(path.pathString)"
        case let .expectedAFile(path):
            return "Could not find a file at path \(path.pathString))"
        case let .nonExistentGlobDirectory(pattern, dirPath):
            return "The directory \"\(dirPath.pathString)\" defined in pattern \"\(pattern)\" does not exist"
        }
    }

    public var type: ErrorType {
        switch self {
        case .invalidTextEncoding:
            return .bug
        case .writingError, .fileNotFound, .unreachableFileSize, .unreachableFileAccessDate, .expectedAFile, .nonExistentGlobDirectory:
            return .abort
        }
    }
}

public enum FileHandlerGlobErrorLevel {
    case none
    case warning
    case error
}

/// Protocol that defines the interface of an object that provides convenient
/// methods to interact with the system files and folders.
public protocol FileHandling: AnyObject {
    /// Returns the current path.
    var currentPath: AbsolutePath { get }

    /// Returns `AbsolutePath` to home directory
    var homeDirectory: AbsolutePath { get }

    func replace(_ to: AbsolutePath, with: AbsolutePath) throws
    func exists(_ path: AbsolutePath) -> Bool
    func move(from: AbsolutePath, to: AbsolutePath) throws
    func copy(from: AbsolutePath, to: AbsolutePath) throws
    func readFile(_ at: AbsolutePath) throws -> Data
    func readTextFile(_ at: AbsolutePath) throws -> String
    func readPlistFile<T: Decodable>(_ at: AbsolutePath) throws -> T
    /// Determine temporary directory either default for user or specified by ENV variable
    func determineTemporaryDirectory() throws -> AbsolutePath
    func temporaryDirectory() throws -> AbsolutePath
    func inTemporaryDirectory(_ closure: @escaping (AbsolutePath) async throws -> Void) async throws
    func inTemporaryDirectory(_ closure: (AbsolutePath) throws -> Void) throws
    func inTemporaryDirectory(removeOnCompletion: Bool, _ closure: (AbsolutePath) throws -> Void) throws
    func inTemporaryDirectory<Result>(_ closure: (AbsolutePath) throws -> Result) throws -> Result
    func inTemporaryDirectory<Result>(removeOnCompletion: Bool, _ closure: (AbsolutePath) throws -> Result) throws -> Result
    func write(_ content: String, path: AbsolutePath, atomically: Bool) throws
    func writePlistFile<T: Encodable>(_ content: T, path: AbsolutePath) throws
    func locateDirectoryTraversingParents(from: AbsolutePath, path: String) -> AbsolutePath?
    func locateDirectory(_ path: String, traversingFrom from: AbsolutePath) throws -> AbsolutePath?
    func glob(_ paths: [AbsolutePath], excluding: [AbsolutePath], errorLevel: FileHandlerGlobErrorLevel, checkFilesExist: Bool) throws -> [AbsolutePath]
    func glob(_ path: AbsolutePath, patterns: [String], exclude: [String]) throws -> [AbsolutePath]
    func glob(_ path: AbsolutePath, glob: String) -> [AbsolutePath]
    func linkFile(atPath: AbsolutePath, toPath: AbsolutePath) throws
    func createFolder(_ path: AbsolutePath) throws
    func delete(_ path: AbsolutePath) throws
    func isFolder(_ path: AbsolutePath) -> Bool
    func touch(_ path: AbsolutePath) throws
    func contentsOfDirectory(_ path: AbsolutePath) throws -> [AbsolutePath]
    func urlSafeBase64MD5(path: AbsolutePath) throws -> String
    func fileSize(path: AbsolutePath) throws -> UInt64
    func fileAccessDate(path: AbsolutePath) throws -> Date
    func fileUpdateAccessDate(path: AbsolutePath, date: Date) throws
    func changeExtension(path: AbsolutePath, to newExtension: String) throws -> AbsolutePath
    func resolveSymlinks(_ path: AbsolutePath) throws -> AbsolutePath
    func createSymbolicLink(at path: AbsolutePath, destination: AbsolutePath) throws
    func fileAttributes(at path: AbsolutePath) throws -> [FileAttributeKey: Any]
    func filesAndDirectoriesContained(in path: AbsolutePath) throws -> [AbsolutePath]?
    func zipItem(at sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws
    func unzipItem(at sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws
}

extension FileHandling {
    public func glob(_ paths: [AbsolutePath], excluding: [AbsolutePath]) throws -> [AbsolutePath] {
        return try self.glob(paths, excluding: excluding, errorLevel: .none, checkFilesExist: false)
    }
}

public class FileHandler: FileHandling {
    // MARK: - Attributes

    public static var shared: FileHandling = FileHandler()
    private let fileManager: FileManager
    private static let cachedCurrentPath = Atomic<AbsolutePath?>(wrappedValue: nil)
    private let propertyListDecoder = PropertyListDecoder()
    private let propertyListEncoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return encoder
    }()

    /// Initializes the file handler with its attributes.
    ///
    /// - Parameter fileManager: File manager instance.
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public var currentPath: AbsolutePath {
        FileHandler.cachedCurrentPath.modify { value in
            if let value {
                return value
            } else {
                let newValue = try! AbsolutePath(validatingAbsolutePath: fileManager.currentDirectoryPath) // swiftlint:disable:this force_try
                value = newValue
                return newValue
            }
        }
    }

    public var homeDirectory: AbsolutePath {
        try! AbsolutePath(validatingAbsolutePath: NSHomeDirectory())  // swiftlint:disable:this force_try
    }

    public func replace(_ to: AbsolutePath, with: AbsolutePath) throws {
        assert(to.isAbsolute)
        assert(with.isAbsolute)

        // To support cases where the destination is on a different volume
        // we need to create a temporary directory that is suitable
        // for performing a `replaceItemAt`
        //
        // References:
        // - https://developer.apple.com/documentation/foundation/filemanager/2293212-replaceitemat
        // - https://developer.apple.com/documentation/foundation/filemanager/1407693-url
        // - https://openradar.appspot.com/50553219
        let rootTempDir = try fileManager.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: to.url,
            create: true
        )
        let tempUrl = rootTempDir.appendingPathComponent("temp")
        defer { try? fileManager.removeItem(at: rootTempDir) }
        try fileManager.copyItem(at: with.url, to: tempUrl)
#if os(macOS)
        _ = try fileManager.replaceItemAt(to.url, withItemAt: tempUrl)
#else
        if isFolder(AbsolutePath(tempUrl.path())) {
            try? fileManager.createDirectory(at: to.url, withIntermediateDirectories: false)
        } else {
            _ = fileManager.createFile(atPath: to.pathString, contents: nil)
        }
        _ = try? fileManager.replaceItemAt(tempUrl, withItemAt: to.url)
#endif
    }

    public func temporaryDirectory() throws -> AbsolutePath {
        let directory = try TemporaryDirectory(removeTreeOnDeinit: false)
        return directory.path
    }

    public func determineTemporaryDirectory() throws -> AbsolutePath {
        try determineTempDirectory()
    }

    public func inTemporaryDirectory<Result>(_ closure: (AbsolutePath) throws -> Result) throws -> Result {
        try withTemporaryDirectory(removeTreeOnDeinit: true, closure)
    }

    public func inTemporaryDirectory(removeOnCompletion: Bool, _ closure: (AbsolutePath) throws -> Void) throws {
        try withTemporaryDirectory(removeTreeOnDeinit: removeOnCompletion, closure)
    }

    public func inTemporaryDirectory(_ closure: (AbsolutePath) throws -> Void) throws {
        try withTemporaryDirectory(removeTreeOnDeinit: true, closure)
    }

    public func inTemporaryDirectory(_ closure: @escaping (AbsolutePath) async throws -> Void) async throws {
        let directory = try TemporaryDirectory(removeTreeOnDeinit: true)
        try await closure(directory.path)
    }

    public func inTemporaryDirectory<Result>(
        removeOnCompletion: Bool,
        _ closure: (AbsolutePath) throws -> Result
    ) throws -> Result {
        try withTemporaryDirectory(removeTreeOnDeinit: removeOnCompletion, closure)
    }

    public func exists(_ path: AbsolutePath) -> Bool {
        assert(path.isAbsolute)
        let exists = self.fileStat(path) != nil
        return exists
    }

    public func fileStat(_ path: AbsolutePath) -> FileStat? {
        var statStruct: stat = .init()
        let result: Int32 = stat(path.pathString, &statStruct)

        guard result == 0 else {
            return nil
        }

        return FileStat(isFolder: statStruct.st_mode & S_IFDIR > 0)
    }

    public func copy(from: AbsolutePath, to: AbsolutePath) throws {
        assert(from.isAbsolute)
        assert(to.isAbsolute)

        logger.debug("Copying file from \(from) to \(to)")
        try fileManager.copyItem(atPath: from.pathString, toPath: to.pathString)
    }

    public func move(from: AbsolutePath, to: AbsolutePath) throws {
        assert(from.isAbsolute)
        assert(to.isAbsolute)

        logger.debug("Moving file from \(from) to \(to)")
        try fileManager.moveItem(atPath: from.pathString, toPath: to.pathString)
    }

    public func readFile(_ at: AbsolutePath) throws -> Data {
        assert(at.isAbsolute)

        logger.debug("Reading contents of file at path \(at)")
        return try Data(contentsOf: at.url)
    }

    public func readTextFile(_ at: AbsolutePath) throws -> String {
        assert(at.isAbsolute)

        logger.debug("Reading contents of text file at path \(at)")
        let data = try Data(contentsOf: at.url)
        if let content = String(data: data, encoding: .utf8) {
            return content
        } else {
            throw FileHandlerError.invalidTextEncoding(at)
        }
    }

    public func readPlistFile<T: Decodable>(_ at: AbsolutePath) throws -> T {
        assert(at.isAbsolute)

        logger.debug("Reading contents of plist file at path \(at)")
        guard let data = fileManager.contents(atPath: at.pathString) else {
            throw FileHandlerError.fileNotFound(at)
        }
        return try propertyListDecoder.decode(T.self, from: data)
    }

    public func writePlistFile<T: Encodable>(_ content: T, path: AbsolutePath) throws {
        assert(path.isAbsolute)

        logger.debug("Writing contents of plist file at path \(path)")
        let data = try propertyListEncoder.encode(content)
        try data.write(to: path.url)
    }

    public func linkFile(atPath: AbsolutePath, toPath: AbsolutePath) throws {
        assert(atPath.isAbsolute)
        assert(toPath.isAbsolute)

        logger.debug("Creating a link from \(atPath) to \(toPath)")
        try fileManager.linkItem(atPath: atPath.pathString, toPath: toPath.pathString)
    }

    public func write(_ content: String, path: AbsolutePath, atomically: Bool) throws {
        assert(path.isAbsolute)

        logger.debug("Writing contents to file \(path) atomically \(atomically)")
        do {
            try content.write(to: path.url, atomically: atomically, encoding: .utf8)
        } catch {}
    }

    public func locateDirectory(_ path: String, traversingFrom from: AbsolutePath) throws -> AbsolutePath? {
        assert(from.isAbsolute)

        logger.debug("Traversing \(from) to locate \(path)")
        let extendedPath = from.appending(try RelativePath(validating: path))
        if exists(extendedPath) {
            return extendedPath
        } else if !from.isRoot {
            return try locateDirectory(path, traversingFrom: from.parentDirectory)
        } else {
            return nil
        }
    }

    public func glob(
        _ paths: [AbsolutePath],
        excluding: [AbsolutePath],
        errorLevel: FileHandlerGlobErrorLevel,
        checkFilesExist: Bool
    ) throws -> [AbsolutePath] {
        var exactPaths: [AbsolutePath] = []
        var globPaths: [AbsolutePath] = []

        for path in paths {
            if Glob.isGlob(path.pathString) {
                globPaths.append(path)
            } else {
                exactPaths.append(path)
            }
        }

        if errorLevel != .none {
            try checkGlobDirectoriesExist(globPaths, throwError: errorLevel == .error)
        }
        if checkFilesExist, errorLevel != .none {
            try self.checkFilesExist(&exactPaths, throwError: errorLevel == .error)
        }

        let globs = globPaths.map { $0.pathString }

        let basePathString = GlobTreeTraverser.basePath(for: globs + excluding.map { $0.pathString })
        let basePath: AbsolutePath = basePathString.isEmpty ? .root : try .init(validatingAbsolutePath: basePathString)
        let dropCount = basePathString.count
        let includeGlobs = globs.map { String($0.dropFirst(dropCount)) }
        let excludeGlobs = excluding.map { String($0.pathString.dropFirst(dropCount)) }

        let globTraverser = try GlobTreeTraverser(includeGlobs, exclude: excludeGlobs)

        if !excludeGlobs.isEmpty {
            exactPaths.removeAll { path in
                guard path.isDescendant(of: basePath) else { return false }

                return globTraverser.globSet.isExcluded(path.relative(to: basePath).pathString)
            }
        }

        if includeGlobs.isEmpty {
            return exactPaths
        }

        return try glob(basePath, globTraverser: globTraverser) + exactPaths
    }

    public func glob(_ path: AbsolutePath, glob: String) -> [AbsolutePath] {
        assert(path.isAbsolute)

        do {
            return try self.glob([path.appending(RelativePath(validatingRelativePath: glob))], excluding: [])
        } catch {
            return []
        }
    }

    public func glob(_ path: AbsolutePath, patterns: [String], exclude: [String]) throws -> [AbsolutePath] {
        assert(path.isAbsolute)

        let resolvedPatternPaths = try patterns.map { try path.appending(RelativePath(validatingRelativePath: $0)) }
        let resolvedExcludePaths = try exclude.map { try path.appending(RelativePath(validatingRelativePath: $0)) }
        return try self.glob(resolvedPatternPaths, excluding: resolvedExcludePaths)
    }

    func checkGlobDirectoriesExist(_ patterns: [AbsolutePath], throwError: Bool) throws {
        for pattern in patterns {
            let basePathStr = GlobTreeTraverser.basePath(for: [pattern.pathString])
            let basePath = try AbsolutePath(validatingAbsolutePath: basePathStr)
            if self.exists(basePath) {
                continue
            }

            if throwError {
                throw FileHandlerError.nonExistentGlobDirectory(pattern.pathString, basePath)
            } else {
                logger.warning("Directory \(basePath) defined in pattern \(pattern.pathString) does not exist")
            }
        }
    }

    func checkFilesExist(_ files: inout [AbsolutePath], throwError: Bool) throws {
        for i in stride(from: files.count - 1, through: 0, by: -1) {
            let file = files[i]

            guard !self.exists(file) else { continue }

            if throwError {
                throw FileHandlerError.fileNotFound(file)
            } else {
                logger.warning("File \(file.pathString) does not exist")
                files.remove(at: i)
            }
        }
    }

    func glob(_ path: AbsolutePath, globTraverser: GlobTreeTraverser) throws -> [AbsolutePath] {
        let cStringArray = CStringArray([path.pathString])

        let fileSystem = fts_open(cStringArray.cArray, FTS_COMFOLLOW | FTS_NOCHDIR, nil)
        guard let fileSystem else { return [] }
        defer { fts_close(fileSystem) }

        var result: [AbsolutePath] = []

        // This is a workaround for skipped folders using fts_set(..., FTS_SKIP)
        // Because there is no way to identify skipped folders during post order traversal
        // using only fts_ent struct, we need to store info about skips outside of fts.
        // But, since post order folders are returned immediately after pre order traversal
        // for skipped folders, it is enough to have a single flag, that will be set to 'true'
        // when the folder is skipped, and on the next pass of fts_read it will be set to 'false'.
        var skippedFolder = false

        while let fileEntry = fts_read(fileSystem) {
            // skip root directory
            guard fileEntry[0].fts_level > 0 else { continue }

            let info = Int32(fileEntry[0].fts_info)

            switch info {
            case FTS_D:
                // pre order traverse directory
                let string = String(cString: fileEntry.pointer(to: \.fts_name)!)
                let (shouldDescend, match) = globTraverser.descend(into: string)
                if match {
                    let string = String(cString: fileEntry[0].fts_path)
                    result.append(try AbsolutePath(validatingAbsolutePath: string))
                }
                if !shouldDescend {
                    fts_set(fileSystem, fileEntry, FTS_SKIP)
                    skippedFolder = true
                }
            case FTS_F:
                // regular file
                let string = String(cString: fileEntry.pointer(to: \.fts_name)!)
                if globTraverser.match(filename: string) {
                    let string = String(cString: fileEntry[0].fts_path)
                    result.append(try AbsolutePath(validatingAbsolutePath: string))
                }
            case FTS_DP:
                // post order traverse of directory
                if skippedFolder {
                    // skipped folders are returned from fts_read()
                    // immediately after previous call with flag FTS_D
                    skippedFolder = false
                    continue
                }
                if globTraverser.globSetStateStack.count > 1 {
                    globTraverser.ascend()
                }

            case FTS_SL:
                // symlink
                fts_set(fileSystem, fileEntry, FTS_FOLLOW)

            default:
                break
            }
        }

        return result
    }

    public func createFolder(_ path: AbsolutePath) throws {
        assert(path.isAbsolute)

        logger.debug("Creating folder at path \(path)")
        try fileManager.createDirectory(
            at: path.url,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    public func delete(_ path: AbsolutePath) throws {
        assert(path.isAbsolute)

        logger.debug("Deleting item at path \(path)")
        if exists(path) {
            try fileManager.removeItem(atPath: path.pathString)
        }
    }

    public func touch(_ path: AbsolutePath) throws {
        assert(path.isAbsolute)

        logger.debug("Touching \(path)")
        try fileManager.createDirectory(
            at: path.removingLastComponent().url,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try Data().write(to: path.url)
    }

    public func isFolder(_ path: AbsolutePath) -> Bool {
        assert(path.isAbsolute)

        let stat = self.fileStat(path)
        return stat?.isFolder == true
    }

    public func locateDirectoryTraversingParents(from: AbsolutePath, path: String) -> AbsolutePath? {
        assert(from.isAbsolute)

        logger.debug("Traversing \(from) to locate \(path)")

        let configPath = from.appending(component: path)

        let root = try! AbsolutePath(validatingAbsolutePath: "/")  // swiftlint:disable:this force_try
        if FileHandler.shared.exists(configPath) {
            return configPath
        } else if from == root {
            return nil
        } else {
            return locateDirectoryTraversingParents(from: from.parentDirectory, path: path)
        }
    }

    public func contentsOfDirectory(_ path: AbsolutePath) throws -> [AbsolutePath] {
        assert(path.isAbsolute)

        guard let dir = opendir(path.pathString) else {
            throw FileHandlerError.fileNotFound(path)
        }

        var result: [AbsolutePath] = []

        while let entry = readdir(dir) {
#if os(macOS)
            let dNamlen = Int(entry.pointee.d_namlen)
#else
            let dNamlen = Int(entry.pointee.d_reclen)
#endif
            let dName = withUnsafePointer(to: &entry.pointee.d_name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: dNamlen) { ptr in
                    String(cString: ptr)
                }
            }

            if dName != "." && dName != ".." {
                result.append(path.appending(component: dName))
            }
        }

        closedir(dir)

        return result
    }

    public func createSymbolicLink(at path: AbsolutePath, destination: AbsolutePath) throws {
        assert(path.isAbsolute)
        assert(destination.isAbsolute)

        try fileManager.createSymbolicLink(atPath: path.pathString, withDestinationPath: destination.pathString)
    }

    public func resolveSymlinks(_ path: AbsolutePath) throws -> AbsolutePath {
        assert(path.isAbsolute)

        return try GekoSupport.resolveSymlinks(path)
    }

    public func fileAttributes(at path: AbsolutePath) throws -> [FileAttributeKey: Any] {
        assert(path.isAbsolute)

        return try fileManager.attributesOfItem(atPath: path.pathString)
    }

    public func filesAndDirectoriesContained(in path: AbsolutePath) throws -> [AbsolutePath]? {
        assert(path.isAbsolute)

        return try FileManager.filesAndDirectories(atPath: path.pathString).map { try AbsolutePath(validatingAbsolutePath: $0) }
    }

    // MARK: - MD5

    public func urlSafeBase64MD5(path: AbsolutePath) throws -> String {
        assert(path.isAbsolute)

        let data = try Data(contentsOf: path.url)
        let digestData = Data(Insecure.MD5.hash(data: data))
        return digestData.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }

    // MARK: - File Attributes

    public func fileSize(path: AbsolutePath) throws -> UInt64 {
        assert(path.isAbsolute)

        let attr = try fileManager.attributesOfItem(atPath: path.pathString)
        guard let size = attr[FileAttributeKey.size] as? UInt64 else { throw FileHandlerError.unreachableFileSize(path) }
        return size
    }

    public func fileAccessDate(path: AbsolutePath) throws -> Date {
        assert(path.isAbsolute)

        let resourceValues = try path.url.resourceValues(forKeys: [.contentAccessDateKey])
        guard let date = resourceValues.contentAccessDate else { throw FileHandlerError.unreachableFileAccessDate(path) }
        return date
    }

    public func fileUpdateAccessDate(path: AbsolutePath, date: Date) throws {
        assert(path.isAbsolute)

        var url = path.url
        var resourceValues = URLResourceValues()
        resourceValues.contentModificationDate = date
        resourceValues.contentAccessDate = date
        try url.setResourceValues(resourceValues)
    }

    // MARK: - Extension

    public func changeExtension(path: AbsolutePath, to fileExtension: String) throws -> AbsolutePath {
        assert(path.isAbsolute)

        guard isFolder(path) == false else { throw FileHandlerError.expectedAFile(path) }
        let sanitizedExtension = fileExtension.starts(with: ".") ? String(fileExtension.dropFirst()) : fileExtension
        guard path.extension != sanitizedExtension else { return path }

        let newPath = path.removingLastComponent().appending(component: "\(path.basenameWithoutExt).\(sanitizedExtension)")
        try move(from: path, to: newPath)
        return newPath
    }

    public func zipItem(at sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws {
        assert(sourcePath.isAbsolute)
        assert(destinationPath.isAbsolute)

        try fileManager.zipItem(at: sourcePath.asURL, to: destinationPath.asURL, shouldKeepParent: false, compressionMethod: .deflate)
    }

    public func unzipItem(at sourcePath: AbsolutePath, to destinationPath: AbsolutePath) throws {
        assert(sourcePath.isAbsolute)
        assert(destinationPath.isAbsolute)

        try fileManager.unzipItem(at: sourcePath.asURL, to: destinationPath.asURL, pathEncoding: .utf8)
    }
}
