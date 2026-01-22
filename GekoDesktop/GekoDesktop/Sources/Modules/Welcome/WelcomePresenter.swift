import AppKit
import Foundation
import TSCBasic

enum WrongURLError: FatalError {
    case wrongURL(String)

    var errorDescription: String? {
        switch self {
        case .wrongURL(let string):
            "Invalid url: \(string)"
        }
    }

    var type: FatalErrorType {
        .abort
    }
}

protocol IWelcomePresenter {
    func prepareItems()
    func itemTapped(_ item: WelcomeItem)
}

final class WelcomePresenter: IWelcomePresenter {
    // MARK: - Attributes

    weak var view: IWelcomeViewStateInput? = nil

    private let applicationStateHolder: IApplicationStateHolder
    private let projectPathProvider: IProjectPathProvider
    private let applicationStateHandler: IApplicationStateHandler
    private let projectSetupAnalytics: IProjectSetupAnalytics
    private let applicationErrorHandler: IApplicationErrorHandler

    init(
        applicationStateHolder: IApplicationStateHolder,
        projectPathProvider: IProjectPathProvider,
        applicationStateHandler: IApplicationStateHandler,
        projectSetupAnalytics: IProjectSetupAnalytics,
        applicationErrorHandler: IApplicationErrorHandler
    ) {
        self.applicationStateHolder = applicationStateHolder
        self.projectPathProvider = projectPathProvider
        self.applicationStateHandler = applicationStateHandler
        self.projectSetupAnalytics = projectSetupAnalytics
        self.applicationErrorHandler = applicationErrorHandler

        applicationStateHolder.addSubscription(self)
    }

    func prepareItems() {
        updateItems(applicationStateHolder.executionState)
    }

    func itemTapped(_ item: WelcomeItem) {
        switch item {
        case .selectProject:
            selectProject()
        case .setupEnvironment:
            changeSelectedSideBar(.config)
        case .generateProject:
            changeSelectedSideBar(.projectGeneration)
        case .gekoDesktopDocumentation:
            tryOpen(Constants.gekoDesktopDocUrl)

        case .gekoDocumentation:
            tryOpen(Constants.gekoDocUrl)
        }
    }
}

// MARK: - IApplicationStateHolderDelegate

extension WelcomePresenter: IApplicationStateHolderDelegate {
    func didChangeExecutionState(_ state: AppState) {
        updateItems(state)
        updateLoadingState(state)
    }

    func didChangeSideBarItem(_ value: SideBarItem, payload: [String: String]?) {}
}

private extension WelcomePresenter {
    func updateItems(_ state: AppState) {
        switch state {
        case .empty:
            view?.didUpdateItems([.gekoDesktopDocumentation, .gekoDocumentation])
        case .prepare, .appOutdated:
            break
        case .wrongEnvironment:
            view?.didUpdateItems([.gekoDesktopDocumentation, .gekoDocumentation])
        case .idle, .executing:
            view?.didUpdateItems([.gekoDesktopDocumentation, .gekoDocumentation])
        }
    }

    func updateLoadingState(_ state: AppState) {
        switch state {
        case .empty, .wrongEnvironment, .idle, .executing, .appOutdated:
            view?.updateLoadingState(false)
        case .prepare:
            view?.updateLoadingState(true)
        }
    }

    func selectProject() {
        Task {
            do {
                let projectPath = try await projectPathProvider.selectProjectPath()
                if let projectPath = projectPath {
                    projectSetupAnalytics.projectDidSelected(projectPath.pathString)
                    applicationStateHandler.setup(projectPath, needReload: true)
                }
            } catch {
                handle(error)
            }
        }
    }

    func handle(_ error: Error) {
        Task {
            await applicationErrorHandler.handle(error)
        }
    }

    func changeSelectedSideBar(_ command: SideBarItem) {
        Task {
            await applicationStateHolder.changeSelectedSideBar(command)
        }
    }

    func tryOpen(_ stringUrl: String) {
        if let url = URL(string: stringUrl) {
            NSWorkspace.shared.open(url)
        } else {
            handle(WrongURLError.wrongURL(Constants.gekoDesktopDocUrl))
        }
    }
}
