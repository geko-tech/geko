import Foundation

protocol IPrepareService {
    func loadCache() async throws
    func prepareCache() async throws
}

final class WorkspacePrepareService: IPrepareService {
    
    private let projectProfilesProvider: IProjectProfilesProvider
    private let workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let cacheDurationAnalytics: ICacheDurationAnalytics
    private let applicationStateHolder: IApplicationStateHolder
    private let terminalStateHolder: ITerminalStateHolder
    private let dumpProvider: IDumpProvider
    private let sessionService: ISessionService
    private let userInfoProvider: IUserInfoProvider
    private let configsProvider: IConfigsProvider
    private let updateAppService: IUpdateAppService
    private let logger: ILogger
    
    init(
        projectProfilesProvider: IProjectProfilesProvider,
        workspaceSettingsProvider: IWorkspaceSettingsProvider,
        cacheDurationAnalytics: ICacheDurationAnalytics,
        applicationStateHolder: IApplicationStateHolder,
        terminalStateHolder: ITerminalStateHolder,
        dumpProvider: IDumpProvider,
        sessionService: ISessionService,
        userInfoProvider: IUserInfoProvider,
        configsProvider: IConfigsProvider,
        updateAppService: IUpdateAppService,
        logger: ILogger
    ) {
        self.projectProfilesProvider = projectProfilesProvider
        self.workspaceSettingsProvider = workspaceSettingsProvider
        self.cacheDurationAnalytics = cacheDurationAnalytics
        self.applicationStateHolder = applicationStateHolder
        self.terminalStateHolder = terminalStateHolder
        self.dumpProvider = dumpProvider
        self.sessionService = sessionService
        self.userInfoProvider = userInfoProvider
        self.configsProvider = configsProvider
        self.updateAppService = updateAppService
        self.logger = logger
    }
    
    func loadCache() async throws {
        guard let project = ProjectsProvider().selectedProject() else {
            clearState()
            return
        }
        do {
            switch try updateAppService.needUpdate() {
            case .updateRequired(let version):
                changeAppState(.appOutdated(version))
            case .updateNotRequired:
                break
            }
        } catch {
            clearState()
            throw error
        }
        loadUserInfo()
        loadState()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        loadConfig(project, needDump: true)
        loadGraph(project, needDump: true, selectedProfile: selectedProfile(project, profiles: loadProfiles()))
        
        let delta = CFAbsoluteTimeGetCurrent() - startTime
        cacheDurationAnalytics.cacheDidLoaded(delta.formatted())
        logger.log(.notice, info: "Workspace loaded \(delta.formatted())")
        logger.log(.notice, info: "All necessary info loaded. Project can be generated!\r\n")
        changeAppState(.idle)   
    }
    
    func prepareCache() async throws {
        guard let project = ProjectsProvider().selectedProject() else {
            clearState()
            return
        }
        do {
            switch try updateAppService.needUpdate() {
            case .updateRequired(let version):
                changeAppState(.appOutdated(version))
            case .updateNotRequired:
                break
            }
        } catch {
            clearState()
            throw error
        }
        
        loadState()
        loadConfig(project, needDump: true)
        loadProfiles()
        loadGraph(project, needDump: false)
        logger.log(.notice, info: "All necessary info loaded. Project can be generated!\r\n")
        changeAppState(.idle)   
    }
    
    private func loadConfig(_ project: UserProject, needDump: Bool) {
        do {
            if needDump || !dumpProvider.configExist(project) {
                workspaceSettingsProvider.config = .loaded(try dumpProvider.dumpConfig(project))
            } else {
                workspaceSettingsProvider.config = .loaded(try dumpProvider.parseConfig(project))
            }
        } catch {
            logger.log(.error, info: "Error while loading config \(error)\r\n")
            workspaceSettingsProvider.config = .error
        }
    }
    
    private func loadGraph(_ project: UserProject, needDump: Bool, selectedProfile: String? = nil) {
        do {
            if needDump || !dumpProvider.graphExist(project) {
                let graph = try dumpProvider.dumpGraph(project, profileName: selectedProfile)
                workspaceSettingsProvider.workspace = .loaded(Workspace(graph: GraphWorkspace(from: graph)))
            } else {
                let graph = try dumpProvider.parseGraph(project)
                workspaceSettingsProvider.workspace = .loaded(Workspace(graph: GraphWorkspace(from: graph)))
            }
        } catch {
            logger.log(.error, info: "Error while loading graph \(error)\r\n")
            workspaceSettingsProvider.workspace = .error
        }
    }
    
    private func selectedProfile(_ project: UserProject, profiles: [ProjectProfile]) -> String? {
        guard let config = configsProvider.selectedConfig(for: project) else {
            return nil
        }
        guard profiles.contains(where: { $0.name == config.profile }) else {
            return nil
        }
        return config.profile
    }
    
    @discardableResult
    private func loadProfiles() -> [ProjectProfile] {
        do {
            let profiles = try projectProfilesProvider.loadProfiles()
            return profiles
        } catch {
            logger.log(.warning, info: "Warning: profiles not found\r\n")
            return []
        }
    }
    
    private func loadUserInfo() {
        Task {
            userInfoProvider.gekoVersion = try sessionService.exec("geko version").removeNewLines()
        }
    }
    
    private func loadState() {
        changeAppState(.prepare("Prepare"))
        workspaceSettingsProvider.workspace = .loading
        workspaceSettingsProvider.config = .loading
    }
    
    private func clearState() {
        workspaceSettingsProvider.workspace = .empty
        workspaceSettingsProvider.config = .empty
        changeAppState(.empty)
    }
    
    private func changeAppState(_ state: AppState) {
        Task {
            await applicationStateHolder.changeExecutionState(state)
        }
    }
}
