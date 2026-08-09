import Foundation

protocol ITerminalStateHolderDelegate: AnyObject {
    func didChangeTerminalState(_ newState: Bool)
    func didSendNewCommand(_ logLevel: LogLevel, message: String)
    func didReceiveTerminalOutput(_ data: Data)
    func didResetSession()
}

protocol ITerminalStateHolder: AnyObject {
    
    var showTerminal: Bool { get }
    
    func addSubscription(_ subscription: some ITerminalStateHolderDelegate)
    
    @MainActor
    func changeTerminalState(_ newState: Bool)
    
    @MainActor
    func sendCommand(_ logLevel: LogLevel, message: String)

    @MainActor
    func sendTerminalOutput(_ data: Data)
    
    @MainActor
    func resetSession()
}

final class TerminalStateHolder: ITerminalStateHolder {
    // MARK: - Properties
    
    var showTerminal: Bool = false
    
    private var subscriptions = DelegatesList<ITerminalStateHolderDelegate>()
    
    // MARK: - ITerminalStateHolder
    
    func addSubscription(_ subscription: some ITerminalStateHolderDelegate) {
        subscriptions.addDelegate(weakify(subscription))
    }
    
    @MainActor
    func changeTerminalState(_ newState: Bool) {
        guard showTerminal != newState else { return }
        showTerminal = newState
        subscriptions.makeIterator().forEach {
            $0.didChangeTerminalState(showTerminal)
        }
    }
    
    @MainActor
    func sendCommand(_ logLevel: LogLevel, message: String) {
        subscriptions.makeIterator().forEach {
            $0.didSendNewCommand(logLevel, message: message)
        }
    }

    @MainActor
    func sendTerminalOutput(_ data: Data) {
        subscriptions.makeIterator().forEach {
            $0.didReceiveTerminalOutput(data)
        }
    }

    @MainActor
    func resetSession() {
        subscriptions.makeIterator().forEach {
            $0.didResetSession()
        }
    }
}
