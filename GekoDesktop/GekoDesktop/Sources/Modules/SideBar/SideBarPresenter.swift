import Foundation

enum UpdatingError: FatalError {
    case needReopen
    case updateDidFailed(version: String)
    
    var errorDescription: String? {
        switch self {
        case .needReopen:
            "The application has been updated, please close the current application and open the new one from the Applications folder."
        case .updateDidFailed:
            """
The update failed, but you can update manually
1) download last version from \(Constants.issuesURL)
2) or download and unzip other version
"""
        }
    }
    
    var type: FatalErrorType {
        switch self {
        case .needReopen:
            .warning
        case .updateDidFailed:
            .abort
        }
    }
}

protocol ISideBarPresenter {
    func didChangeSideBarSelectedItem(_ value: SideBarItem, payload: [String: String]?)
    func changeExecutingState(_ isExecuting: Bool)
    func checkVersionUpdate()
    func updateApp()
}

extension ISideBarPresenter {
    func didChangeSideBarSelectedItem(_ value: SideBarItem) {
        didChangeSideBarSelectedItem(value, payload: nil)
    }
}

final class SideBarPresenter: ISideBarPresenter {
    // MARK: - Attributes
    
    private let applicationStateHolder: IApplicationStateHolder
    private let updateAppService: IUpdateAppService
    private let errorHandler: IApplicationErrorHandler
    private let projectGenerationHandler: IProjectGenerationHandler
    private var latestVersion: String?
    
    weak var view: ISideBarViewStateInput? = nil
    
    // MARK: - Initialization
    
    init(
        applicationStateHolder: IApplicationStateHolder,
        updateAppService: IUpdateAppService,
        applicationErrorHandler: IApplicationErrorHandler,
        projectGenerationHandler: IProjectGenerationHandler
    ) {
        self.applicationStateHolder = applicationStateHolder
        self.updateAppService = updateAppService
        self.errorHandler = applicationErrorHandler
        self.projectGenerationHandler = projectGenerationHandler
        
        applicationStateHolder.addSubscription(self)
    }
 
    // MARK: - ISideBarPresenter
    
    @MainActor
    func didChangeSideBarSelectedItem(_ value: SideBarItem, payload: [String: String]?) {
        applicationStateHolder.changeSelectedSideBar(value)
    }
    
    func changeExecutingState(_ isExecuting: Bool) {
        isExecuting ? startProjectGeneration() : cancelProjectGeneration()
    }
    
    func checkVersionUpdate() {
        Task {
            do {
                view?.updateUpdatingState(true)
                let lastVersion = try updateAppService.lastAvailableVersion().removeNewLines()
                self.latestVersion = lastVersion
                await MainActor.run {
                    view?.updateLastAvailableVersion(lastVersion)
                    view?.updateUpdatingState(false)
                }
            } catch {
                await MainActor.run {
                    errorHandler.handle(error)
                    view?.updateUpdatingState(false)
                }
            }
        }
    }
    
    func updateApp() {
        guard let latestVersion = latestVersion else {
            return
        }
        Task {
            do {
                view?.updateUpdatingState(true)
                try updateAppService.updateApp(version: latestVersion)
                view?.updateUpdatingState(false)
                await MainActor.run { 
                    errorHandler.handle(UpdatingError.needReopen)
                }
            } catch {
                await MainActor.run {
                    if let lastVersion = try? updateAppService.lastAvailableVersion() {
                        errorHandler.handle(UpdatingError.updateDidFailed(version: lastVersion))
                    } else {
                        errorHandler.handle(error)
                    }
                    view?.updateUpdatingState(false)
                }
            }
        }
    }
}

// MARK: - IApplicationStateHolderDelegate

extension SideBarPresenter: IApplicationStateHolderDelegate {
    
    func didChangeExecutionState(_ value: AppState) {
        switch value {
        case .empty, .appOutdated:
            view?.updateGenerationButtonState(false)
            view?.updateExecutingState(false)
        case .prepare:
            view?.updateGenerationButtonState(false)
            view?.updateExecutingState(true)
        case .wrongEnvironment:
            view?.updateGenerationButtonState(false)
            view?.updateExecutingState(false)
        case .idle:
            view?.updateGenerationButtonState(true)
            view?.updateExecutingState(false)
        case .executing:
            view?.updateGenerationButtonState(true)
            view?.updateExecutingState(true)
        }
    }
    
    func didChangeSideBarItem(_ value: SideBarItem, payload: [String: String]?) {
        view?.commandDidSelected(value)
    }
}

private extension SideBarPresenter {
    func startProjectGeneration() {
        do {
            try projectGenerationHandler.generate()
        } catch {
            Task {
                await MainActor.run {
                    errorHandler.handle(error)
                }
            }
        }
    }
    
    func cancelProjectGeneration() {
        projectGenerationHandler.stopGenerate()
    }
    
    func changeState(_ state: AppState) {
        Task {
            await applicationStateHolder.changeExecutionState(state)
        }
    }
}
