import Foundation
import ProjectDescription

public enum FileUnarchiverError: FatalError {
    case unknownArchiveType
    case cannotOpenFile

    public var type: ErrorType { .abort }

    public var description: String {
        switch self {
        case .unknownArchiveType:
            return "unknown archive type"
        case .cannotOpenFile:
            return "cannot open archive"
        }
    }
}

/// An interface to unarchive files from a zip file.
public protocol FileUnarchiving {
    func unarchive() throws -> AbsolutePath

    /// Unarchives the files into a temporary directory and returns the path to that directory.
    func unzip() throws -> AbsolutePath

    func untar(flatten: Bool) throws -> AbsolutePath

    /// Call this method to delete the temporary directory where the .zip file has been generated.
    func delete() throws
}

public extension FileUnarchiving {
    func untar() throws -> AbsolutePath {
        try untar(flatten: true)
    }
}

public class FileUnarchiver: FileUnarchiving {

    private enum ArchiveType {
        case tgz
        case zip
        case unknown
    }

    /// Path to the .zip file to unarchive
    private let path: AbsolutePath

    /// Temporary directory in which the .zip file will be generated.
    private var temporaryDirectory: AbsolutePath

    /// Initializes the unarchiver with the path to the file to unarchive.
    /// - Parameter path: Path to the .zip file to unarchive.
    public init(path: AbsolutePath) throws {
        self.path = path
        temporaryDirectory = try TemporaryDirectory(removeTreeOnDeinit: false).path
    }

    public func unarchive() throws -> AbsolutePath {
        switch try archiveType() {
        case .zip:
            return try unzip()
        case .tgz:
            return try untar()
        case .unknown:
            throw FileUnarchiverError.unknownArchiveType
        }
    }

    private func archiveType() throws -> ArchiveType {
        guard let inputStream = InputStream(fileAtPath: path.pathString) else {
            throw FileUnarchiverError.cannotOpenFile
        }
        inputStream.open()
        defer { inputStream.close() }

        let buffer = UnsafeMutableRawPointer.allocate(byteCount: 4, alignment: 1)
        defer { buffer.deallocate() }

        guard inputStream.read(buffer.bindMemory(to: UInt8.self, capacity: 4), maxLength: 4) == 4 else {
            return .unknown
        }

        if buffer.loadUnaligned(as: UInt16.self).littleEndian == 0x8b_1f {
            return .tgz
        }

        let uint32 = buffer.loadUnaligned(as: UInt32.self).littleEndian
        switch uint32 {
        case 0x04_03_4b_50, 0x06_05_4b_50, 0x08_07_4b_50:
            return .zip
        default:
            return .unknown
        }
    }

    public func unzip() throws -> AbsolutePath {
        try FileHandler.shared.unzipItem(at: path, to: temporaryDirectory)
        return temporaryDirectory
    }

    public func delete() throws {
        try FileHandler.shared.delete(temporaryDirectory)
    }

    public func untar(flatten: Bool = true) throws -> AbsolutePath {
        let gzipStream = try GzipStream.create(filepath: path)
        var tarStream = TarStream(gzipStream: gzipStream)
        do {
            try tarStream.untar(path: temporaryDirectory)
        } catch {
            tarStream.gzipStream.destroy()
            throw error
        }
        tarStream.gzipStream.destroy()

        let contents = try FileHandler.shared.contentsOfDirectory(temporaryDirectory)
        if contents.count == 1, FileHandler.shared.isFolder(contents[0]) {
            return contents[0]
        }

        return temporaryDirectory
    }
}
