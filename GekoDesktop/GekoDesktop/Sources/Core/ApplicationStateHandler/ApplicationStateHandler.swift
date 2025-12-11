import Foundation
import TSCBasic

protocol IApplicationStateHandler {
    func setup(_ path: AbsolutePath, needReload: Bool)
}

final class ApplicationStateHandler: IApplicationStateHandler {
    
    private let applicationStateHolder: IApplicationStateHolder
    private let applicationErrorHandler: IApplicationErrorHandler
    private let projectsProvider: IProjectsProvider
    private let gitCacheProvider: IGitCacheProvider
    private let prepareService: IPrepareService
    
    private var prepareTask: Task<(), Error>?
    
    init(
        applicationStateHolder: IApplicationStateHolder,
        applicationErrorHandler: IApplicationErrorHandler,
        projectsProvider: IProjectsProvider,
        gitCacheProvider: IGitCacheProvider,
        prepareService: IPrepareService
    ) {
        self.applicationStateHolder = applicationStateHolder
        self.applicationErrorHandler = applicationErrorHandler
        self.projectsProvider = projectsProvider
        self.gitCacheProvider = gitCacheProvider
        self.prepareService = prepareService
        
        gitCacheProvider.addSubscription(self)
    }
    
    deinit {
        prepareTask?.cancel()
    }
    
    func setup(_ path: AbsolutePath, needReload: Bool) {
        prepareTask?.cancel()
        prepareTask = Task {
            do {
                if needReload {
                    try await prepareService.loadCache()
                } else {
                    try await prepareService.prepareCache()
                }
                try Task.checkCancellation()
            } catch _ as CancellationError {
                /// return if task is cancelled
                return
            } catch {
                changeState(.wrongEnvironment)
                handle(error)
            }
            
        }
    }
    
    private func trySetup() {
        guard let path = projectsProvider.selectedProject()?.clearPath() else {
            handle(InconsistentStateError.inconsistentState)
            return
        }
        setup(path, needReload: true)
    }
    
    private func handle(_ error: Error) {
        Task {
            await applicationErrorHandler.handle(error)
        }
    }
    
    private func changeState(_ state: AppState) {
        Task {
            await applicationStateHolder.changeExecutionState(state)
        }
    }
}

// MARK: - IGitCacheProviderDelegate

extension ApplicationStateHandler: IGitCacheProviderDelegate {
    func event(_ gitEvent: GitEvent) {
        switch gitEvent {
        case .pull, .checkout:
            trySetup()
        default: break
        }
    }
}
