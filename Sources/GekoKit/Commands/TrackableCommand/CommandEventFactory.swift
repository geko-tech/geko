import Foundation
import GekoAnalytics
import GekoSupport

/// `CommandEventTagger` builds a `CommandEvent` by grouping information
/// from different sources and tells `analyticsTagger` to send the event to a provider

public final class CommandEventFactory {
    private let machineEnvironment: MachineEnvironmentRetrieving

    public init(
        machineEnvironment: MachineEnvironmentRetrieving = MachineEnvironment.shared
    ) {
        self.machineEnvironment = machineEnvironment
    }

    public func make(from info: TrackableCommandInfo) -> CommandEvent {
        let commandEvent = CommandEvent(
            name: info.name,
            subcommand: info.subcommand,
            params: info.parameters,
            commandArguments: info.commandArguments,
            durationInMs: Int(info.durationInMs),
            clientId: machineEnvironment.clientId,
            gekoVersion: Constants.version,
            swiftVersion: machineEnvironment.swiftVersion,
            os: machineEnvironment.os,
            osVersion: machineEnvironment.osVersion,
            machineHardwareName: machineEnvironment.hardwareName,
            isCI: machineEnvironment.isCI,
            isError: info.isError
        )
        return commandEvent
    }
}
