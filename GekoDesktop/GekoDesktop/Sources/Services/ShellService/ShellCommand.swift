import Combine
import Foundation

struct ShellCommand {
    enum ShellCommandResultType {
        case collected
        case stream
        case void
    }

    enum ShellCommandResult {
        case collected(Data)
        case stream(AnyPublisher<SystemEvent<Data>, Error>)
        case void(Cancellable)
    }

    let logInput: Bool
    let silence: Bool
    let inputFile: String?
    let arguments: [String]
    let resultType: ShellCommandResultType
    
    init(
        logInput: Bool = true,
        silence: Bool = false,
        inputFile: String? = nil,
        arguments: [String],
        resultType: ShellCommandResultType = .collected
    ) {
        self.logInput = logInput
        self.silence = silence
        self.inputFile = inputFile
        self.arguments = arguments
        self.resultType = resultType
    }
}
