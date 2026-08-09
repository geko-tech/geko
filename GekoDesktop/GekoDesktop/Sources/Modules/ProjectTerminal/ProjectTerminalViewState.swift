import SwiftUI

protocol IProjectTerminalViewStateOutput: ObservableObject {
    var terminalViewWrapper: TerminalViewWrapper { get }
} 

protocol IProjectTerminalViewStateInput: AnyObject {
    func feed(_ command: String)
    func feed(_ data: Data)
    func reset()
}

@Observable
final class ProjectTerminalViewState: IProjectTerminalViewStateInput & IProjectTerminalViewStateOutput {
    // MARK: - Attributes
    
    var terminalViewWrapper: TerminalViewWrapper
    
    private let presenter: IProjectTerminalPresenter
    private let terminalView: TerminalView
    private let terminal: Terminal
    
    init(presenter: IProjectTerminalPresenter) {
        self.presenter = presenter
        terminalView = TerminalView()
        terminal = terminalView.getTerminal()
        terminal.options = TerminalOptions(convertEol: true, scrollback: 5000)
        terminal.resetToInitialState()
        terminalViewWrapper = TerminalViewWrapper(terminalView: terminalView)
    }
    
    // MARK: - IProjectTerminalViewStateInput
    
    func feed(_ command: String) {
        terminalView.feed(text: command)
    }

    func feed(_ data: Data) {
        terminalView.feed(byteArray: Array(data)[...])
    }
    
    func reset() {
        terminal.resetToInitialState()
    }
}
