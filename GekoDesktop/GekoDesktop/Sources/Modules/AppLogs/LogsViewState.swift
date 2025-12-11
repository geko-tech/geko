import SwiftUI

protocol ILogsViewStateOutput: ObservableObject {
    func readLogs() -> [String]
    func openLogsDirectory()
}

final class LogsViewState: ILogsViewStateOutput {
    // MARK: - Attributes
    
    private let presenter: ILogsPresenter
    
    // MARK: - Initialization
    
    init(presenter: ILogsPresenter) {
        self.presenter = presenter
    }
    
    func readLogs() -> [String] {
        presenter.readLogs()
    }
    
    func openLogsDirectory() {
        presenter.openLogsDirectory()
    }
}
