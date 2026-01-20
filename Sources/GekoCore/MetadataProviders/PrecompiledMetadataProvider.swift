import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

enum PrecompiledMetadataProviderError: FatalError, Equatable {
    case architecturesNotFound(AbsolutePath)
    case metadataNotFound(AbsolutePath)

    // MARK: - FatalError

    var description: String {
        switch self {
        case let .architecturesNotFound(path):
            return "Couldn't find architectures for binary at path \(path.pathString)"
        case let .metadataNotFound(path):
            return "Couldn't find metadata for binary at path \(path.pathString)"
        }
    }

    var type: ErrorType {
        switch self {
        case .architecturesNotFound:
            return .abort
        case .metadataNotFound:
            return .abort
        }
    }
}

public protocol PrecompiledMetadataProviding {
    /// It returns the supported architectures of the binary at the given path.
    /// - Parameter binaryPath: Binary path.
    func architectures(binaryPath: AbsolutePath) throws -> [BinaryArchitecture]

    /// Return how other binaries should link the binary at the given path.
    /// - Parameter binaryPath: Path to the binary.
    func linking(binaryPath: AbsolutePath) throws -> BinaryLinking

    /// It uses 'dwarfdump' to dump the UUIDs of each architecture.
    /// The UUIDs allows us to know which .bcsymbolmap files belong to this binary.
    /// - Parameter binaryPath: Path to the binary.
    func uuids(binaryPath: AbsolutePath) throws -> Set<UUID>
}

/// PrecompiledMetadataProvider reads a framework/library metadata using the Mach-o file format.
/// Useful documentation:
/// - https://opensource.apple.com/source/cctools/cctools-809/misc/lipo.c
/// - https://opensource.apple.com/source/xnu/xnu-4903.221.2/EXTERNAL_HEADERS/mach-o/loader.h.auto.html

public class PrecompiledMetadataProvider: PrecompiledMetadataProviding {
    public func architectures(binaryPath: AbsolutePath) throws -> [BinaryArchitecture] {
        let metadata = try readMetadatas(binaryPath: binaryPath)
        return metadata.map(\.0)
    }

    public func linking(binaryPath: AbsolutePath) throws -> BinaryLinking {
        let metadata = try readMetadatas(binaryPath: binaryPath)
        return metadata.contains { $0.1 == BinaryLinking.dynamic } ? .dynamic : .static
    }

    public func uuids(binaryPath: AbsolutePath) throws -> Set<UUID> {
        let metadata = try readMetadatas(binaryPath: binaryPath)
        return Set(metadata.compactMap(\.2))
    }

    // swiftlint:disable:next large_tuple
    typealias Metadata = (BinaryArchitecture, BinaryLinking, UUID?)

    private let sizeOfArchiveHeader: UInt64 = 60
    private let archiveHeaderSizeOffset: UInt64 = 56
    private let archiveFormatMagic = "!<arch>\n"
    private let archiveExtendedFormat = "#1/"

    func readMetadatas(binaryPath: AbsolutePath) throws -> [Metadata] {
        guard let binary = FileHandle(forReadingAtPath: binaryPath.pathString) else {
            throw PrecompiledMetadataProviderError.metadataNotFound(binaryPath)
        }

        defer {
            binary.closeFile()
        }

        let magic: UInt32 = binary.read()
        binary.seek(to: 0)

        if isFat(magic) {
            return try readMetadatasFromFatHeader(binary: binary, binaryPath: binaryPath)
        } else if let metadata = try readMetadataFromMachHeaderIfAvailable(binary: binary) {
            return [metadata]
        } else {
            throw PrecompiledMetadataProviderError.metadataNotFound(binaryPath)
        }
    }

    private func readMetadatasFromFatHeader(
        binary: FileHandle,
        binaryPath: AbsolutePath
        // swiftlint:disable:next large_tuple
    ) throws -> [(BinaryArchitecture, BinaryLinking, UUID?)] {
        let currentOffset = binary.currentOffset
        let magic: UInt32 = binary.read()
        binary.seek(to: currentOffset)

        let _header: fat_header = binary.read()
        let swapBytes: Bool
#if _endian(big)
        swapBytes = magic == FAT_MAGIC || magic == FAT_MAGIC_64
#else
        swapBytes = magic == FAT_CIGAM || magic == FAT_CIGAM_64
#endif
        let header = ByteSwapper(_header, swap: swapBytes)

        return try (0 ..< header.nfat_arch).map { _ in
            let _fatArch: fat_arch = binary.read()
            let fatArch = ByteSwapper(_fatArch, swap: swapBytes)
            let currentOffset = binary.currentOffset

            binary.seek(to: UInt64(fatArch.offset))
            if let value = try readMetadataFromMachHeaderIfAvailable(binary: binary) {
                binary.seek(to: currentOffset)
                return value
            } else {
                binary.seek(to: currentOffset)

                guard let architecture = readBinaryArchitecture(cputype: fatArch.cputype, cpusubtype: fatArch.cpusubtype) else {
                    throw PrecompiledMetadataProviderError.architecturesNotFound(binaryPath)
                }

                return (architecture, .static, nil)
            }
        }
    }

    // swiftlint:disable:next function_body_length large_tuple
    private func readMetadataFromMachHeaderIfAvailable(binary: FileHandle) throws -> (BinaryArchitecture, BinaryLinking, UUID?)? {
        readArchiveFormatIfAvailable(binary: binary)

        let currentOffset = binary.currentOffset
        let magic: UInt32 = binary.read()
        binary.seek(to: currentOffset)

        guard isMagic(magic) else { return nil }

        let cputype: cpu_type_t
        let cpusubtype: cpu_subtype_t
        let filetype: UInt32
        let numOfCommands: UInt32

        let swapBytes: Bool
#if _endian(big)
        swapBytes = magic == FAT_MAGIC || magic == FAT_MAGIC_64
#else
        swapBytes = magic == FAT_CIGAM || magic == FAT_CIGAM_64
#endif

        if is64(magic) {
            let _header: mach_header_64 = binary.read()
            let header = ByteSwapper(_header, swap: swapBytes)

            cputype = header.cputype
            cpusubtype = header.cpusubtype
            filetype = header.filetype
            numOfCommands = header.ncmds
        } else {
            let _header: mach_header = binary.read()
            let header = ByteSwapper(_header, swap: swapBytes)

            cputype = header.cputype
            cpusubtype = header.cpusubtype
            filetype = header.filetype
            numOfCommands = header.ncmds
        }

        guard let binaryArchitecture = readBinaryArchitecture(cputype: cputype, cpusubtype: cpusubtype)
        else { return nil }

        var uuid: UUID?

        for _ in 0 ..< numOfCommands {
            let currentOffset = binary.currentOffset
            let _loadCommand: load_command = binary.read()

            let loadCommand = ByteSwapper(_loadCommand, swap: swapBytes)

            guard loadCommand.cmd == LC_UUID else {
                binary.seek(to: currentOffset + UInt64(loadCommand.cmdsize))
                continue
            }

            binary.seek(to: currentOffset)

            let _uuidCommand: uuid_command = binary.read()
            let uuidStruct = ByteSwapper(_uuidCommand.uuid, swap: swapBytes)
            let swapped = (
                uuidStruct.0,
                uuidStruct.1,
                uuidStruct.2,
                uuidStruct.3,
                uuidStruct.4,
                uuidStruct.5,
                uuidStruct.6,
                uuidStruct.7,
                uuidStruct.8,
                uuidStruct.9,
                uuidStruct.10,
                uuidStruct.11,
                uuidStruct.12,
                uuidStruct.13,
                uuidStruct.14,
                uuidStruct.15
            )
            uuid = UUID(uuid: swapped)
            break
        }

        let binaryLinking = filetype == MH_DYLIB ? BinaryLinking.dynamic : BinaryLinking.static
        return (binaryArchitecture, binaryLinking, uuid)
    }

    private func readBinaryArchitecture(cputype: cpu_type_t, cpusubtype: cpu_subtype_t) -> BinaryArchitecture? {
#if os(macOS)
        guard let archInfo = NXGetArchInfoFromCpuType(cputype, cpusubtype),
              let arch = BinaryArchitecture(rawValue: String(cString: archInfo.pointee.name))
        else {
            return nil
        }
        return arch
#else
        let _CPU_ARCH_ABI64: Int32 = 0x01000000
        let cpuTypeNames: [cpu_type_t: String] = [
            7: "i386",
            _CPU_ARCH_ABI64 | 7: "x86_64",
            12: "arm",
            _CPU_ARCH_ABI64 | 12: "arm64",
        ]
        let armSubtypeSuffix: [cpu_subtype_t: String] = [
            9: "v7",
            11: "v7s",
            12: "v7k"
        ]

        let arm64SubtypeSuffix: [cpu_subtype_t: String] = [
            0: "",
            2: "e",
        ]
        func binaryArch(cputype: cpu_type_t, cpusubtype: cpu_subtype_t, suffixMap: [cpu_subtype_t: String]) -> BinaryArchitecture? {
            if let subtypeSuffix = suffixMap[cpusubtype] {
                return BinaryArchitecture(rawValue: cpuTypeNames[cputype, default: ""] + subtypeSuffix)
            }
            return nil
        }
        if cputype == 12 {
            return binaryArch(cputype: cputype, cpusubtype: cpusubtype, suffixMap: armSubtypeSuffix)
        }
        if cputype == (_CPU_ARCH_ABI64 | 12) {
            return binaryArch(cputype: cputype, cpusubtype: cpusubtype, suffixMap: arm64SubtypeSuffix)
        }
        return cpuTypeNames[cputype].flatMap(BinaryArchitecture.init(rawValue:))
#endif
    }

    private func readArchiveFormatIfAvailable(binary: FileHandle) {
        let currentOffset = binary.currentOffset
        let magic = binary.readData(ofLength: 8)
        binary.seek(to: currentOffset)

        guard String(data: magic, encoding: .ascii) == archiveFormatMagic else { return }

        binary.seek(to: currentOffset + archiveHeaderSizeOffset)
        guard let sizeString = binary.readString(ofLength: 10) else { return }

        let size = strtoul(sizeString, nil, 10)
        binary.seek(to: 8 + sizeOfArchiveHeader + UInt64(size))

        guard let name = binary.readString(ofLength: 16) else { return }
        binary.seek(to: binary.currentOffset - 16)

        if name.hasPrefix(archiveExtendedFormat) {
            let nameSize = strtoul(String(name.dropFirst(3)), nil, 10)
            binary.seek(to: binary.currentOffset + sizeOfArchiveHeader + UInt64(nameSize))
        } else {
            binary.seek(to: binary.currentOffset + sizeOfArchiveHeader)
        }
    }

    private func isMagic(_ magic: UInt32) -> Bool {
        [MH_MAGIC, MH_MAGIC_64, MH_CIGAM, MH_CIGAM_64, FAT_MAGIC, FAT_CIGAM].contains(magic)
    }

    private func is64(_ magic: UInt32) -> Bool {
        [MH_MAGIC_64, MH_CIGAM_64].contains(magic)
    }

    private func shouldSwap(_ magic: UInt32) -> Bool {
        [MH_CIGAM, MH_CIGAM_64, FAT_CIGAM].contains(magic)
    }

    private func isFat(_ magic: UInt32) -> Bool {
        [FAT_MAGIC, FAT_CIGAM].contains(magic)
    }
}

extension FileHandle {
    fileprivate var currentOffset: UInt64 { offsetInFile }

    fileprivate func seek(to offset: UInt64) {
        seek(toFileOffset: offset)
    }

    fileprivate func read<T>() -> T {
        readData(ofLength: MemoryLayout<T>.size).withUnsafeBytes { $0.load(as: T.self) }
    }

    fileprivate func readString(ofLength length: Int) -> String? {
        let sizeData = readData(ofLength: length)
        return String(data: sizeData, encoding: .ascii)
    }
}

#if !os(macOs)
typealias cpu_type_t = Int32
typealias cpu_subtype_t = Int32

var FAT_MAGIC: UInt32 = 0xCAFEBABE
var FAT_CIGAM: UInt32 = 0xBEBAFECA
var FAT_MAGIC_64: UInt32 = 0xCAFEBABF
var FAT_CIGAM_64: UInt32 = 0xBFBAFECA

var MH_MAGIC: UInt32 = 0xFEEDFACE
var MH_CIGAM: UInt32 = 0xCEFAEDFE
var MH_MAGIC_64: UInt32 = 0xFEEDFACF
var MH_CIGAM_64: UInt32 = 0xCFFAEDFE

var MH_OBJECT: UInt32 = 0x1
var MH_EXECUTE: UInt32 = 0x2
var MH_FVMLIB: UInt32 = 0x3
var MH_CORE: UInt32 = 0x4
var MH_PRELOAD: UInt32 = 0x5
var MH_DYLIB: UInt32 = 0x6
var MH_DYLINKER: UInt32 = 0x7
var MH_BUNDLE: UInt32 = 0x8
var MH_DYLIB_STUB: UInt32 = 0x9
var MH_DSYM: UInt32 = 0xa

var LC_UUID: UInt32 = 0x1b

struct load_command {
    var cmd: UInt32

    var cmdsize: UInt32
}

struct uuid_command {
    var cmd: UInt32

    var cmdsize: UInt32

    var uuid: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
}

struct mach_header {
    var magic: UInt32

    var cputype: Int32

    var cpusubtype: Int32

    var filetype: UInt32

    var ncmds: UInt32

    var sizeofcmds: UInt32

    var flags: UInt32
}

struct mach_header_64 {
    var magic: UInt32

    var cputype: Int32

    var cpusubtype: Int32

    var filetype: UInt32

    var ncmds: UInt32

    var sizeofcmds: UInt32

    var flags: UInt32

    var reserved: UInt32
}

struct fat_arch {
    var cputype: Int32

    var cpusubtype: Int32

    var offset: UInt32

    var size: UInt32

    var align: UInt32
}

struct fat_header {
    var magic: UInt32

    var nfat_arch: UInt32
}

#endif

@dynamicMemberLookup
private struct ByteSwapper<T> {
    private let wrappedValue: T
    private let swap: Bool

    init(_ value: T, swap: Bool) {
        self.wrappedValue = value
        self.swap = swap
    }

    subscript<U: FixedWidthInteger>(dynamicMember k: KeyPath<T, U>) -> U {
        get {
            swap ? wrappedValue[keyPath: k].byteSwapped : wrappedValue[keyPath: k]
        }
    }
}
