import AnyCodable
import Foundation

/// A `CommandEvent` is the analytics event to track the execution of a Geko command
public struct CommandEvent: Codable, Equatable {
    public let name: String
    public let subcommand: String?
    public let params: [String: AnyCodable]
    public let commandArguments: [String]
    public let durationInMs: Int
    public let clientId: String
    public let gekoVersion: String
    public let swiftVersion: String
    public let os: String
    public let osVersion: String
    public let machineHardwareName: String
    public let isCI: Bool
    public let isError: Bool
    public let id = UUID()
    public let date = Date()

    private enum CodingKeys: String, CodingKey {
        case name
        case subcommand
        case params
        case commandArguments = "command_arguments"
        case durationInMs = "duration_in_ms"
        case clientId = "client_id"
        case gekoVersion = "geko_version"
        case swiftVersion = "swift_version"
        case os
        case osVersion = "os_version"
        case machineHardwareName = "machine_hardware_name"
        case isCI = "is_ci"
        case isError = "is_error"
    }

    public init(
        name: String,
        subcommand: String?,
        params: [String: AnyCodable],
        commandArguments: [String],
        durationInMs: Int,
        clientId: String,
        gekoVersion: String,
        swiftVersion: String,
        os: String,
        osVersion: String,
        machineHardwareName: String,
        isCI: Bool,
        isError: Bool
    ) {
        self.name = name
        self.subcommand = subcommand
        self.params = params
        self.commandArguments = commandArguments
        self.durationInMs = durationInMs
        self.clientId = clientId
        self.gekoVersion = gekoVersion
        self.swiftVersion = swiftVersion
        self.os = os
        self.osVersion = osVersion
        self.machineHardwareName = machineHardwareName
        self.isCI = isCI
        self.isError = isError
    }
}
