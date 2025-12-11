import Crypto
import Foundation

public protocol MachineEnvironmentRetrieving {
    var clientId: String { get }
    var os: String { get }
    var osVersion: String { get }
    var swiftVersion: String { get }
    var hardwareName: String { get }
    var isCI: Bool { get }
}

/// `MachineEnvironment` is a data structure that contains information about the machine executing Geko
public class MachineEnvironment: MachineEnvironmentRetrieving {
    public static let shared = MachineEnvironment()
    private init() {}

    public var os: String {
#if os(macOS)
        return "macOS"
#else
        return "linux"
#endif
    }

    /// `clientId` is a unique anonymous hash that identifies the machine running Geko
    public lazy var clientId: String = {
#if os(macOS)
        let matchingDict = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, matchingDict)
        defer { IOObjectRelease(platformExpert) }
        guard platformExpert != 0 else {
            fatalError("Couldn't obtain the platform expert")
        }
        let uuid = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        ).takeRetainedValue() as! String // swiftlint:disable:this force_cast
        return Insecure.MD5.hash(data: uuid.data(using: .utf8)!)
            .compactMap { String(format: "%02x", $0) }.joined()
#elseif os(Linux)
        if let machineID = linuxMachineID() {
            return Insecure.MD5.hash(data: machineID.data(using: .utf8)!)
                .compactMap { String(format: "%02x", $0) }.joined()
        }
        fatalError("Couldn't obtain the linux machine id")
#else
        fatalError("Not supported OS")
#endif
    }()

    /// The `osVersion` of the machine running Geko, in the format major.minor.path, e.g: "10.15.7"
    public lazy var osVersion = """
    \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\
    \(ProcessInfo.processInfo.operatingSystemVersion.minorVersion).\
    \(ProcessInfo.processInfo.operatingSystemVersion.patchVersion)
    """

    /// The `swiftVersion` of the machine running Geko
#if os(macOS)
    public lazy var swiftVersion = try! System.shared // swiftlint:disable:this force_try
        .capture(["/usr/bin/xcrun", "swift", "-version"])
        .components(separatedBy: "Swift version ").last!
        .components(separatedBy: " ").first!
#else
    public lazy var swiftVersion = try! System.shared // swiftlint:disable:this force_try
        .capture(["swift", "--version"])
        .components(separatedBy: "Swift version ").last!
        .components(separatedBy: " ").first!
#endif

    /// `hardwareName` is the name of the architecture of the machine running Geko, e.g: "arm64" or "x86_64"
    public lazy var hardwareName = ProcessInfo.processInfo.machineHardwareName

    /// Indicates whether Geko is running in Continuous Integration (CI) environment
    public var isCI: Bool {
        CIChecker().isCI()
    }

#if os(Linux)
    private func linuxMachineID() -> String? {
        let possibleMachineIDPaths = [
            "/etc/machine-id",
            "/var/lib/dbus/machine-id",
            "/sys/class/dmi/id/product_uuid"
        ]

        for path in possibleMachineIDPaths {
            if let data = FileManager.default.contents(atPath: path),
               var str = String(data: data, encoding: .utf8) {
                str = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if !str.isEmpty {
                    return str
                }
            }
        }
        return nil
    }
#endif
}

extension ProcessInfo {
    /// Returns a `String` representing the machine hardware name
    var machineHardwareName: String {
        var sysinfo = utsname()
        let result = uname(&sysinfo)
        guard result == EXIT_SUCCESS else { fatalError("uname result is \(result)") }
#if os(macOS)
        let count = _SYS_NAMELEN
#else
        let count = SYS_NMLN
#endif
        let data = Data(bytes: &sysinfo.machine, count: Int(count))
        return String(bytes: data, encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
    }
}
