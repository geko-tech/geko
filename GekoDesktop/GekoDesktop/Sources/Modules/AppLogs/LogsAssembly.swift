import SwiftUI

final class LogsAssembly {
    // MARK: - Attributes
    
    private let logWritter: ILogWritter
    private let logDirectoryProvider: ILogDirectoryProvider
    
    /// Cache the view to avoid re-creating the module when re-rendering
    private var view: (any View)?
    
    // MARK: - Initialization
    
    init(logWritter: ILogWritter, logDirectoryProvider: ILogDirectoryProvider) {
        self.logWritter = logWritter
        self.logDirectoryProvider = logDirectoryProvider
    }
    
    @MainActor
    func build() -> any View {
        if let view = view {
            return view
        }
        let presenter = LogsPresenter(
            logWritter: logWritter,
            logDirectoryProvider: logDirectoryProvider
        )
        let viewState = LogsViewState(presenter: presenter)
        
        let view = LogsView(viewState: viewState)
        self.view = view
        return view
    }
}
