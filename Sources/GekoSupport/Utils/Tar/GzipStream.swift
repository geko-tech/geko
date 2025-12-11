import Foundation
import ProjectDescription
#if os(macOS)
import zlib
#else
import CZlib
#endif

private let bufferMaxSize = 131072  // 128 KB

enum GzipError: FatalError {
    case cannotOpenFile
    case cannotInitializeZlibStream
    case corruptedGzipFile

    var type: ErrorType { .abort }

    var description: String {
        switch self {
        case .cannotOpenFile:
            return "cannot open file"
        case .cannotInitializeZlibStream:
            return "cannot initialize z_stream"
        case .corruptedGzipFile:
            return "corrupted gzip file"
        }
    }
}

// https://datatracker.ietf.org/doc/html/rfc1952
struct GzipStream: ~Copyable {
    private(set) var outputBuffer: UnsafeMutablePointer<UInt8>
    private(set) var outputBufferSize: Int
    private(set) var available: Int
    private(set) var atEnd: Bool

    private var fileStream: InputStream
    private var inputBuffer: UnsafeMutablePointer<UInt8>
    private var inputBufferPos: Int
    private var inputBufferSize: Int
    private var zStream: UnsafeMutablePointer<z_stream>

    private init(
        fileStream: InputStream,
        available: Int,
        zStream: UnsafeMutablePointer<z_stream>
    ) {
        self.outputBuffer = .allocate(capacity: bufferMaxSize)
        self.outputBufferSize = 0
        self.available = available
        self.atEnd = false

        self.fileStream = fileStream
        self.inputBuffer = .allocate(capacity: bufferMaxSize)
        self.inputBufferPos = 0
        self.inputBufferSize = 0
        self.zStream = zStream
    }

    static func create(filepath: AbsolutePath) throws -> GzipStream {
        let attrs = try FileManager.default.attributesOfItem(atPath: filepath.pathString)
        let fileSize = attrs[FileAttributeKey.size] as! UInt64

        guard let fileStream = InputStream(fileAtPath: filepath.pathString) else {
            throw GzipError.cannotOpenFile
        }

        let zStream = UnsafeMutablePointer<z_stream>.allocate(capacity: 1)
        zStream.initialize(to: z_stream())
        zStream.pointee.zalloc = nil
        zStream.pointee.zfree = nil
        zStream.pointee.opaque = nil

        let code = inflateInit2_(zStream, 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard code == Z_OK else {
            zStream.deinitialize(count: 1)
            zStream.deallocate()
            throw GzipError.cannotInitializeZlibStream
        }

        return .init(
            fileStream: fileStream,
            available: Int(fileSize),
            zStream: zStream
        )
    }

    func destroy() {
        inflateEnd(zStream)
        zStream.deinitialize(count: 1)
        zStream.deallocate()
        outputBuffer.deallocate()
        inputBuffer.deallocate()
        fileStream.close()
    }

    @discardableResult
    private mutating func readFileChunk() -> Int {
        guard available > 0 else {
            return 0
        }

        let bytesRead = fileStream.read(inputBuffer, maxLength: min(available, bufferMaxSize))
        available -= bytesRead
        inputBufferPos = 0
        inputBufferSize = bytesRead
        return bytesRead
    }

    private mutating func advanceIfNeeded() {
        if available > 0 && inputBufferPos >= inputBufferSize {
            readFileChunk()
        }
    }

    mutating func decompressChunk() throws {
        if atEnd { return }

        if fileStream.streamStatus == .notOpen {
            fileStream.open()
        }

        zStream.pointee.next_out = outputBuffer
        zStream.pointee.avail_out = UInt32(bufferMaxSize)

        while zStream.pointee.avail_out > 0 && (available > 0 || zStream.pointee.avail_in > 0) {
            advanceIfNeeded()

            zStream.pointee.next_in = inputBuffer + inputBufferPos
            zStream.pointee.avail_in = UInt32(inputBufferSize - inputBufferPos)

            let result = inflate(zStream, Z_NO_FLUSH)

            switch result {
            case Z_STREAM_END:
                inputBufferPos = zStream.pointee.next_in - UnsafeMutablePointer(inputBuffer)
                outputBufferSize = zStream.pointee.next_out - outputBuffer
                atEnd = true
                return
            case Z_OK:
                inputBufferPos = zStream.pointee.next_in - UnsafeMutablePointer(inputBuffer)
                outputBufferSize = zStream.pointee.next_out - outputBuffer
            default:
                throw GzipError.corruptedGzipFile
            }
        }
    }
}
