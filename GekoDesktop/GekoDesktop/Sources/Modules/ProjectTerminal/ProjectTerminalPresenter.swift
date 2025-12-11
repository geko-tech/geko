import Foundation

protocol IProjectTerminalPresenter {}

final class ProjectTerminalPresenter: IProjectTerminalPresenter {
    // MARK: - Attributes
    
    weak var view: IProjectTerminalViewStateInput? = nil
    
    private var sessionCommands: [String] = []
    private let terminalStateHolder: ITerminalStateHolder
    
    init(terminalStateHolder: ITerminalStateHolder) {
        self.terminalStateHolder = terminalStateHolder
        terminalStateHolder.addSubscription(self)
    }
}

extension ProjectTerminalPresenter: ITerminalStateHolderDelegate {
    func didChangeTerminalState(_ newState: Bool) {}
    
    func didSendNewCommand(_ logLevel: LogLevel, message: String) {
        switch logLevel {
        case .trace, .debug, .info:
            sessionCommands.append(message)
            view?.feed(message)
        case .notice:
            sessionCommands.append(message)
            view?.feed(message.green)
        case .warning:
            sessionCommands.append(message)
            view?.feed(message.yellow)
        case .error, .critical:
            sessionCommands.append(message)
            view?.feed(message.red)
        }
    }
    
    func didResetSession() {
        sessionCommands = []
        view?.reset()
    }
}

fileprivate extension String {
    var yellow: String {
        "\u{001B}[0;33m\(self)\u{001B}[0m"
    }
    
    var red: String {
        "\u{001B}[0;31m\(self)\u{001B}[0m"
    }
    
    var green: String {
        "\u{001B}[0;32m\(self)\u{001B}[0m"
    }
}
