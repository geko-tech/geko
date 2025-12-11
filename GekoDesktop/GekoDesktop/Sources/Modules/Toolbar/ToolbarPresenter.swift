import Foundation
import TSCBasic

enum InconsistentStateError: FatalError {
    case inconsistentState
    case willBeLater
    case emptyProjects

    var type: FatalErrorType {
        switch self {
        case .inconsistentState:
            .abort
        case .willBeLater:
            .warning
        case .emptyProjects:
            .abort
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .inconsistentState:
            "Inconsistent application state"
        case .willBeLater:
            "This feature will be available later"
        case .emptyProjects:
            "This project not supported yet"
        }
    }
}

protocol IToolbarPresenter {
    func chooseProjectDirectory()
    func chooseGitBranch()
    func onAppear()
}

final class ToolbarPresenter: IToolbarPresenter {
    // MARK: - Attributes
    
    weak var view: IToolbarViewStateInput? = nil
    
    private let applicationStateHolder: IApplicationStateHolder
    private let applicationErrorHandler: IApplicationErrorHandler
    private let applicationStateHandler: IApplicationStateHandler
    private let projectPathProvider: IProjectPathProvider
    private let projectSetupAnalytics: IProjectSetupAnalytics
    
    private var gitBranch: String? = nil
    private var onAppearDidCalled = false
    
    // MARK: - Initialization
    
    init(
        applicationStateHolder: IApplicationStateHolder,
        applicationErrorHandler: IApplicationErrorHandler,
        applicationStateHandler: IApplicationStateHandler,
        projectPathProvider: IProjectPathProvider,
        projectSetupAnalytics: IProjectSetupAnalytics
    ) {
        self.applicationStateHolder = applicationStateHolder
        self.applicationErrorHandler = applicationErrorHandler
        self.applicationStateHandler = applicationStateHandler
        self.projectPathProvider = projectPathProvider
        self.projectSetupAnalytics = projectSetupAnalytics
        
        applicationStateHolder.addSubscription(self)
    }
    
    func onAppear() {
        guard !onAppearDidCalled else {
            return
        }
        onAppearDidCalled.toggle()
    }
    
    func chooseProjectDirectory() {}
    
    func chooseGitBranch() {
        handle(InconsistentStateError.willBeLater)
    }
}

// MARK: - IApplicationStateHolderDelegate

extension ToolbarPresenter: IApplicationStateHolderDelegate {
    func didChangeExecutionState(_ value: AppState) {
        switch value {
        case .empty:
            view?.updateToolbarState(.empty)
        default:
            view?.updateToolbarState(.empty)
        }
    }
    
    func didChangeSideBarItem(_ value: SideBarItem, payload: [String: String]?) {}
}
private extension ToolbarPresenter {

    func handle(_ error: Error) {
        Task {
            await applicationErrorHandler.handle(error)
        }
    }
}
