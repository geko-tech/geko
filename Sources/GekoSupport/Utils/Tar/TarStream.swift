import Foundation
import SystemPackage
import ProjectDescription

// block size of tarball
private let tarBlockSize = 512

enum TarError: FatalError {
    case corruptedTarball
    case escapingFile(RelativePath)
    case cannotCreateFile
    case wrongHeaderChecksum

    var type: ErrorType { .abort }

    var description: String {
        switch self {
        case .corruptedTarball:
            return "Corrupted tarball"
        case let .escapingFile(path):
            return "file \(path) inside tarball will rewrite file outside of temporary directory. Aborting."
        case .cannotCreateFile:
            return "cannot create file"
        case .wrongHeaderChecksum:
            return "invalid tar header checksum"
        }
    }
}

enum TarEntryType: UInt8 {
    case aRegularFile = 0 // "\0"
    case regularFile = 48 // "0"
    case hardLink = 49 // "1"
    case symbolicLink = 50 // "2"
    case characterSpecial = 51 // "3"
    case blockSpecial = 52 // "4"
    case directory = 53 // "5"
    case fifoSpecial = 54 // "6"
    case contiguous = 55 // "7"

    // extended headers
    case longLinkName = 75
    case longName = 76
    case sunExtendedHeader = 88
    case globalExtendedHeader = 103
    case localExtendedHeader = 120
}

enum TarEntryFormat {
    case gnu
    case ustar
    case prePosix
}

struct TarHeader {
    let name: String
    let linkName: String
    let attrs: FilePermissions
    let size: Int
    let entryType: TarEntryType
    let mtime: Date?
    let atime: Date?
    let ctime: Date?
    let prefix: String?
    let format: TarEntryFormat
}

struct TarExtendedHeader {
    var atime: Date?
    var ctime: Date?
    var mtime: Date?

    var size: Int?
    var uid: Int?
    var gid: Int?
    var uname: String?
    var gname: String?

    var path: String?
    var linkPath: String?

    var charset: String?
    var comment: String?
}

// https://www.gnu.org/software/tar/manual/html_node/Standard.html
struct TarStream: ~Copyable {
    var gzipStream: GzipStream
    var gzipBufferPos: Int = 0

    var lastLocalExtendedHeader: TarExtendedHeader?
    var lastGlobalExtendedHeader: TarExtendedHeader?
    var longLinkName: String?
    var longName: String?

    var atEnd: Bool {
        gzipStream.atEnd && gzipBufferPos >= gzipStream.outputBufferSize
    }

    @inlinable
    mutating func loadMoreIfNeeded() throws {
        guard !atEnd, gzipBufferPos >= gzipStream.outputBufferSize else { return }

        try loadMore()
    }

    @inlinable
    mutating func loadMore() throws {
        try gzipStream.decompressChunk()
        gzipBufferPos = 0
    }

    mutating func cString(maxLength: Int) -> String {
        var data = Data(bytes: gzipStream.outputBuffer + gzipBufferPos, count: maxLength)
        if data.last != 0 {
            data.append(contentsOf: [0])
        }

        gzipBufferPos += maxLength

        return data.withUnsafeBytes { (p: UnsafeRawBufferPointer) -> String in
            p.withMemoryRebound(to: CChar.self) {
                return String(cString: $0.baseAddress!)
            }
        }
    }

    mutating func string(length: Int, encoding: String.Encoding = .utf8) throws -> String? {
        var result = Data()
        var remaining = length

        while remaining > 0 && !atEnd {
            if gzipBufferPos + remaining < gzipStream.outputBufferSize {
                result += Data(bytes: gzipStream.outputBuffer + gzipBufferPos, count: remaining)
                gzipBufferPos += remaining
                break
            }

            let chunkSize = gzipStream.outputBufferSize - gzipBufferPos
            result += Data(bytes: gzipStream.outputBuffer + gzipBufferPos, count: chunkSize)
            remaining -= chunkSize
            try loadMore()
        }

        return String(data: result, encoding: encoding)
    }

    mutating func base256Int(maxLength: Int) throws -> Int {
        let invMask = gzipStream.outputBuffer[gzipBufferPos] & 0x40 != 0 ? 0xFF : 0x00

        var result = 0
        for i in 0 ..< maxLength {
            var byte = Int(gzipStream.outputBuffer[gzipBufferPos + i]) ^ invMask
            if i == 0 {
                byte &= 0x7f
            }
            if result >> (Int.bitWidth - 8) > 0 {
                throw TarError.corruptedTarball
            }
            result = result << 8 | byte
        }
        if result >> (Int.bitWidth - 1) > 0 {
            throw TarError.corruptedTarball
        }

        gzipBufferPos += maxLength

        return invMask == 0xff ? ~result : result
    }

    mutating func octInt(maxLength: Int) -> Int {
        let o0: UInt8 = Character("0").asciiValue!
        let o7: UInt8 = Character("7").asciiValue!
        var result: Int = 0
        var len = maxLength

        while (gzipStream.outputBuffer[gzipBufferPos] < o0 || gzipStream.outputBuffer[gzipBufferPos] > o7) && len > 0 {
            gzipBufferPos += 1
            len -= 1
        }
        while (gzipStream.outputBuffer[gzipBufferPos] >= o0 && gzipStream.outputBuffer[gzipBufferPos] <= o7) && len > 0 {
            result *= 8
            result += Int(gzipStream.outputBuffer[gzipBufferPos] - o0)
            gzipBufferPos += 1
            len -= 1
        }
        gzipBufferPos += len

        return result
    }

    mutating func int(maxLength: Int) throws -> Int {
        if gzipStream.outputBuffer[gzipBufferPos] & 0x80 > 0 {
            return try base256Int(maxLength: maxLength)
        }
        return octInt(maxLength: maxLength)
    }

    mutating func uint64() -> UInt64 {
        defer { gzipBufferPos += 8 }
        return UnsafeMutableRawPointer(gzipStream.outputBuffer + gzipBufferPos).loadUnaligned(as: UInt64.self)
    }

    mutating func skip(length: Int) {
        gzipBufferPos += length
    }

    mutating func entryType() throws -> TarEntryType {
        let byte = gzipStream.outputBuffer[gzipBufferPos]
        gzipBufferPos += 1

        guard let entryType = TarEntryType(rawValue: byte) else {
            throw TarError.corruptedTarball
        }

        return entryType
    }

    func calculateHeaderChecksum() -> UInt64 {
        var result: UInt64 = 0

        let p = gzipStream.outputBuffer + gzipBufferPos
        var i = 0

        while i < tarBlockSize {
            // checksum itself is not included in the checksum calculation
            if i >= 148 && i < 156 {
                result += 0x20 // treat checksum as spaces
            } else {
                result += UInt64((p + i).pointee)
            }
            i += 1
        }

        return result
    }

    mutating func header() throws -> TarHeader {
        let calculatedChecksum = calculateHeaderChecksum()

        // 0
        let name = cString(maxLength: 100)
        // 100
        let attrs = try FilePermissions(rawValue: CModeT(int(maxLength: 8)))
        // 108
        skip(length: 16) // skip uid and gid
        // 124
        let size = try int(maxLength: 12)
        // 136
        let mtime = try int(maxLength: 12)
        // 148
        let checksum = try int(maxLength: 8)
        guard checksum == calculatedChecksum else {
            throw TarError.wrongHeaderChecksum
        }
        // 156
        let entryType = try entryType()
        // 157
        let linkName = cString(maxLength: 100)
        // 257
        let magic = uint64()
        // 265

        var atime: Date?
        var ctime: Date?
        var prefix: String?

        let format: TarEntryFormat

        if magic == 0x0020207261747375 || magic == 0x3030007261747375 || magic == 0x3030207261747375 {
            skip(length: 32) // uname
            skip(length: 32) // gname
            skip(length: 8) // device major
            skip(length: 8) // device minor
            if magic == 0x00_20_20_72_61_74_73_75 {
                atime = try Date(timeIntervalSince1970: TimeInterval(int(maxLength: 12)))
                ctime = try Date(timeIntervalSince1970: TimeInterval(int(maxLength: 12)))
                format = .gnu
            } else {
                prefix = cString(maxLength: 155)
                format = .ustar
            }
        } else {
            // this does not mean that tar is correct, just assume it is
            // if tarball is incorrect, then we will fail down the line
            format = .prePosix
        }

        return .init(
            name: name,
            linkName: linkName,
            attrs: attrs,
            size: size,
            entryType: entryType,
            mtime: Date(timeIntervalSince1970: TimeInterval(mtime)),
            atime: atime,
            ctime: ctime,
            prefix: prefix,
            format: format
        )
    }

    mutating func extendedHeader(size: Int) throws -> TarExtendedHeader {
        var result = TarExtendedHeader()
        var headerLength = size

        func nextHeaderByte() throws {
            gzipBufferPos += 1
            headerLength -= 1
            try loadMoreIfNeeded()
        }

        func extendedHeaderString(terminator: UInt8) throws -> String? {
            try loadMoreIfNeeded()
            var result = Data()
            var start = gzipBufferPos
            while headerLength > 0 && gzipStream.outputBuffer[gzipBufferPos] != terminator {
                gzipBufferPos += 1
                headerLength -= 1
                if gzipBufferPos >= gzipStream.outputBufferSize {
                    result += Data(buffer: .init(start: gzipStream.outputBuffer + start, count: gzipBufferPos - start))
                    try loadMore()
                    start = gzipBufferPos
                }
            }
            result += Data(buffer: .init(start: gzipStream.outputBuffer + start, count: gzipBufferPos - start))
            try nextHeaderByte()

            return String(data: result, encoding: .utf8)
        }

        func extendedHeaderString(length: Int) throws -> String? {
            guard length < headerLength else {
                throw TarError.corruptedTarball
            }

            headerLength -= length
            return try string(length: length, encoding: .ascii)
        }

        while headerLength > 0 {
            try loadMoreIfNeeded()
            let lengthStartPos = gzipBufferPos
            guard let lengthString = try extendedHeaderString(terminator: 0x20 /* space */),
                  let recordLength = Int(lengthString) else {
                throw TarError.corruptedTarball
            }

            guard let key = try extendedHeaderString(terminator: 0x3d /* "=" */) else {
                throw TarError.corruptedTarball
            }

            let valueLength = recordLength - (gzipBufferPos - lengthStartPos) - 1
            guard let value = try extendedHeaderString(length: valueLength) else {
                throw TarError.corruptedTarball
            }

            guard gzipStream.outputBuffer[gzipBufferPos] == 0x0a /* "\n" */ else {
                throw TarError.corruptedTarball
            }
            try nextHeaderByte() // skip terminator

            switch key {
            case "uid":
                result.uid = Int(value)
            case "gid":
                result.gid = Int(value)
            case "uname":
                result.uname = value
            case "gname":
                result.gname = value
            case "size":
                result.size = Int(value)
            case "atime":
                result.atime = Double(value).map { Date(timeIntervalSince1970: $0)}
            case "ctime":
                result.ctime = Double(value).map { Date(timeIntervalSince1970: $0)}
            case "mtime":
                result.mtime = Double(value).map { Date(timeIntervalSince1970: $0)}
            case "path":
                result.path = value
            case "linkpath":
                result.linkPath = value
            case "charset":
                result.charset = value
            case "comment":
                result.comment = value
            default:
                break // unknown key
            }
        }

        return result
    }

    func isZeroBlock() throws -> Bool {
        guard !atEnd else {
            throw TarError.corruptedTarball
        }

        var len = tarBlockSize
        var p = gzipStream.outputBuffer + gzipBufferPos
        while len > 0 {
            if p.pointee != 0 {
                return false
            }
            len -= 1
            p += 1
        }
        return true
    }

    func filepath(for header: TarHeader, path: AbsolutePath) throws -> AbsolutePath {
        var filePath: RelativePath
        if let extendedHeaderPath = lastLocalExtendedHeader?.path ?? lastGlobalExtendedHeader?.path {
            filePath = try RelativePath(validating: extendedHeaderPath)
        } else {
            filePath = try RelativePath(validating: header.name)
            if let prefix = header.prefix, prefix != "" {
                let prefixPath = try RelativePath(validating: prefix)
                filePath = prefixPath.appending(filePath)
            }
        }

        let result = path.appending(filePath)

        guard path.isAncestorOfOrEqual(to: result) else {
            throw TarError.escapingFile(filePath)
        }

        return result
    }

    mutating func writeFile(path: AbsolutePath, header: TarHeader) throws {
        let filePath = try filepath(for: header, path: path)

        var size = lastLocalExtendedHeader?.size ?? lastGlobalExtendedHeader?.size ?? header.size

        if !FileManager.default.fileExists(atPath: filePath.dirname) {
            try FileManager.default.createDirectory(at: URL(filePath: filePath.dirname), withIntermediateDirectories: true)
        }

        guard let outputStream = OutputStream(
            toFileAtPath: filePath.pathString,
            append: false
        ) else {
            throw TarError.cannotCreateFile
        }
        outputStream.open()

        while size > 0 && !atEnd {
            try loadMoreIfNeeded()

            if gzipBufferPos + size < gzipStream.outputBufferSize {
                outputStream.write(gzipStream.outputBuffer + gzipBufferPos, maxLength: size)
                gzipBufferPos += size
                break
            }

            let chunkSize = gzipStream.outputBufferSize - gzipBufferPos
            outputStream.write(gzipStream.outputBuffer + gzipBufferPos, maxLength: chunkSize)
            size -= chunkSize
            gzipBufferPos += chunkSize
        }

        outputStream.close()
        try! setAttrs(filepath: filePath, header: header)
    }

    func createDirectory(path: AbsolutePath, header: TarHeader) throws {
        let filePath = try filepath(for: header, path: path)

        try FileHandler.shared.createFolder(filePath)
        try! setAttrs(filepath: filePath, header: header)
    }

    func setAttrs(filepath: AbsolutePath, header: TarHeader) throws {
        var attrs: [FileAttributeKey: Any] = [:]

        attrs[FileAttributeKey.posixPermissions] = header.attrs.rawValue
        if let cdate = lastLocalExtendedHeader?.ctime ?? lastGlobalExtendedHeader?.ctime ?? header.ctime {
            attrs[FileAttributeKey.creationDate] = cdate
        }
        if let mdate = lastLocalExtendedHeader?.mtime ?? lastGlobalExtendedHeader?.mtime ?? header.mtime {
            attrs[FileAttributeKey.creationDate] = mdate
        }
        if let adate = lastLocalExtendedHeader?.atime ?? lastGlobalExtendedHeader?.atime ?? header.atime {
            attrs[FileAttributeKey.creationDate] = adate
        }

        try FileManager.default.setAttributes(attrs, ofItemAtPath: filepath.pathString)
    }

    mutating func roundToBlockSize() {
        guard gzipBufferPos % tarBlockSize > 0 else { return }

        gzipBufferPos += 512 - (gzipBufferPos % 512)
    }

    mutating func untar(path: AbsolutePath) throws {
        while !atEnd {
            try loadMoreIfNeeded()

            guard gzipStream.outputBufferSize % tarBlockSize == 0 else {
                throw TarError.corruptedTarball
            }

            if try isZeroBlock() {
                skip(length: tarBlockSize)
                try loadMoreIfNeeded()
                if try isZeroBlock() {
                    skip(length: tarBlockSize)
                    try loadMoreIfNeeded()
                    break // end of tarball
                } else {
                    throw TarError.corruptedTarball
                }
            }

            let header = try header()
            roundToBlockSize()

            switch header.entryType {
            case .aRegularFile, .regularFile:
                try writeFile(path: path, header: header)
            case .hardLink:
                skip(length: header.size) // TODO
            case .symbolicLink:
                skip(length: header.size) // TODO
            case .directory:
                try createDirectory(path: path, header: header)
                skip(length: header.size) // TODO
            case .longLinkName:
                guard let name = try string(length: header.size) else {
                    throw TarError.corruptedTarball
                }
                longLinkName = name
            case .longName:
                guard let name = try string(length: header.size) else {
                    throw TarError.corruptedTarball
                }
                longName = name
            case .globalExtendedHeader:
                lastGlobalExtendedHeader = try extendedHeader(size: header.size)
            case .localExtendedHeader, .sunExtendedHeader:
                lastLocalExtendedHeader = try extendedHeader(size: header.size)
            case .fifoSpecial, .contiguous, .characterSpecial, .blockSpecial:
                // skip special files
                skip(length: header.size)
            }

            roundToBlockSize()
        }
    }
}
