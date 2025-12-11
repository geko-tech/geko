import SwiftUI

final class ProjectTerminalAssembly {
    
    private let terminalStateHolder: ITerminalStateHolder
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
    init(terminalStateHolder: ITerminalStateHolder) {
        self.terminalStateHolder = terminalStateHolder
    }
    
    @MainActor
    func build() -> any View {
        if let view = view {
            return view
        }
        let presenter = ProjectTerminalPresenter(terminalStateHolder: terminalStateHolder)
        let viewState = ProjectTerminalViewState(presenter: presenter)
        presenter.view = viewState
        
        let view = ProjectTerminalView(viewState: viewState)

        self.view = view
        return view
    }
}
