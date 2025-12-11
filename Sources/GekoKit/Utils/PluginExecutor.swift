import Foundation
import GekoSupport

protocol IPluginExecutor {
    func execute(arguments: [String]) throws
}

final class PluginExecutor: IPluginExecutor {
    func execute(arguments: [String]) throws {
        try System.shared.runAndPrint(
            arguments,
            verbose: Environment.shared.isVerbose,
            environment: System.shared.env
        )
    }
}
