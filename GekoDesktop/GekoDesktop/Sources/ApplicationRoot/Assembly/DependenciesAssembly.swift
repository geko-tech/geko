import Foundation

@MainActor @Observable
final class DependenciesAssembly: ManualDIAssembly {}

// MARK: - UI

extension DependenciesAssembly {
    var mainViewAssembly: MainAssembly {
        resolve(scope: .singleton) {
            MainAssembly(
                applicationStateHolder: applicationStateHolder,
                applicationStateHandler: applicationStateHandler,
                applicationErrorHandler: applicationErrorHandler,
                terminalStateHolder: terminalStateHolder,
                sessionService: sessionService,
                configsProvider: configsProvider,
                projectsProvider: projectsProvider,
                gitCacheProvider: gitCacheProvider,
                updateAppService: updateAppService,
                logger: logger
            )
        }
    }
    
    var sideBarAssembly: SideBarAssembly {
        resolve(scope: .singleton) {
            SideBarAssembly(
                applicationStateHolder: applicationStateHolder,
                updateAppService: updateAppService,
                applicationErrorHandler: applicationErrorHandler,
                projectGenerationHandler: projectGenerationHandler
            )
        }
    }
    
    var workspaceInspectorAssembly: WorkspaceInspectorAssembly {
        resolve(scope: .singleton) { 
            WorkspaceInspectorAssembly(
                workspaceSettingsProvider: workspaceSettingsProvider,
                workspaceInspectorTreeBuilder: workspaceInspectorTreeBuilder,
                prepareService: prepareService,
                configsProvider: configsProvider,
                projectsProvider: projectsProvider
            )
        }
    }
    
    var projectTerminalAssembly: ProjectTerminalAssembly {
        resolve(scope: .singleton) { 
            ProjectTerminalAssembly(terminalStateHolder: terminalStateHolder)
        }
    }
    
    var logsAssebly: LogsAssembly {
        resolve(scope: .singleton) { 
            LogsAssembly(logWritter: logWritter, logDirectoryProvider: logDirectoryProvider)
        }
    }
    
    var projectPickerAssembly: ProjectPickerAssembly {
        resolve(scope: .singleton) { 
            ProjectPickerAssembly(
                projectsProvider: projectsProvider,
                projectPathProvider: projectPathProvider,
                applicationErrorHandler: applicationErrorHandler
            )
        }
    }
    
    var gekoDesktopSettingsAssembly: GekoDesktopSettingsAssembly {
        resolve(scope: .singleton) { 
            GekoDesktopSettingsAssembly(
                applicationErrorHandler: applicationErrorHandler,
                workspaceSettingsProvider: workspaceSettingsProvider,
                applicationStateHolder: applicationStateHolder,
                projectsProvider: projectsProvider,
                applicationStateHandler: applicationStateHandler,
                sessionService: sessionService,
                updateAppService: updateAppService,
                userInfoProvider: userInfoProvider,
                configsProvider: configsProvider
            )
        }
    }
    
    var toolbarAssembly: ToolbarAssembly {
        resolve(scope: .singleton) { 
            ToolbarAssembly(
                applicationStateHolder: applicationStateHolder,
                applicationErrorHandler: applicationErrorHandler,
                applicationStateHandler: applicationStateHandler,
                projectPathProvider: projectPathProvider,
                projectSetupAnalytics: projectSetupAnalytics
            )
        }
    }
    
    var welcomeAssembly: WelcomeAssembly {
        resolve(scope: .singleton) { 
            WelcomeAssembly(
                applicationStateHolder: applicationStateHolder,
                projectPathProvider: projectPathProvider,
                applicationStateHandler: applicationStateHandler,
                projectSetupAnalytics: projectSetupAnalytics,
                applicationErrorHandler: applicationErrorHandler
            )
        }
    }
    
    var gekoConfigAssembly: GekoConfigAssembly {
        resolve(scope: .singleton) { 
            GekoConfigAssembly(
                workspaceSettingsProvider: workspaceSettingsProvider,
                sessionService: sessionService,
                dumpProvider: dumpProvider,
                projectsProvider: projectsProvider
            )
        }
    }
    
    var sourcesEditorAssembly: SourcesEditorAssembly {
        resolve(scope: .singleton) { 
            SourcesEditorAssembly(
                workspaceSettingsProvider: workspaceSettingsProvider,
                configsProvider: configsProvider,
                projectsProvider: projectsProvider
            )
        }
    }
    
    var shortcutEditorAssembly: ShortcutEditorAssembly {
        resolve(scope: .singleton) {
            ShortcutEditorAssembly(
                sessionService: sessionService,
                applicationErrorHandler: applicationErrorHandler,
                shortcutsProvider: shortcutsProvider,
                projectsProvider: projectsProvider
            )
        }
    }
    
    var additionalOptionsAssembly: AdditionalOptionsEditorAssembly {
        resolve(scope: .singleton) { 
            AdditionalOptionsEditorAssembly(
                configProvider: configsProvider,
                projectsProvider: projectsProvider
            )
        }
    }
    
    var projectGeneration1Assembly: ProjectGenerationAssembly {
        resolve(scope: .singleton) { 
            ProjectGenerationAssembly(
                workspaceSettingsProvider: workspaceSettingsProvider,
                configsProvider: configsProvider,
                prepareService: prepareService,
                projectProfilesProvider: projectProfilesProvider,
                genCommandBuilder: genCommandBuilder,
                projectsProvider: projectsProvider,
                projectGenerationHandler: projectGenerationHandler,
                sessionService: sessionService,
                applicationErrorHandler: applicationErrorHandler,
                applicationStateHolder: applicationStateHolder
            )
        }
    }
    
    var gitShortcutsAssembly: GitShortcutsAssembly {
        resolve(scope: .singleton) {
            GitShortcutsAssembly(
                shortcutsProvider: shortcutsProvider,
                sessionService: sessionService,
                projectsProvider: projectsProvider,
                applicationErrorHandler: applicationErrorHandler,
                applicationStateHolder: applicationStateHolder
            )
        }
    }
    
    var applicationStateHolder: IApplicationStateHolder {
        resolve(scope: .singleton) {
            ApplicationStateHolder()
        }
    }
    
    var shortcutsProvider: IGitShortcutsProvider {
        resolve(scope: .singleton) {
            GitShortcutsProvider(projectsProvider: projectsProvider, sessionService: sessionService)
        }
    }
}

// MARK: - Services

private extension DependenciesAssembly {
    var sessionService: ISessionService {
        resolve(scope: .singleton) { 
            SessionService(logger: logger)
        }
    }
    
    var pathFinderService: IPathFinderService {
        resolve(scope: .singleton) {
            PathFinderService()
        }
    }
    
    var logger: ILogger {
        resolve(scope: .singleton) { 
            Logger(
                logWritter: logWritter,
                terminalStateHolder: terminalStateHolder,
                projectsProvider: projectsProvider,
                userInfoProvider: userInfoProvider
            )
        }
    }

    var logDirectoryProvider: ILogDirectoryProvider {
        resolve(scope: .singleton) {
            LogDirectoryProvider(projectPathProvider: projectPathProvider)
        }
    }
    
    var terminalStateHolder: ITerminalStateHolder {
        resolve(scope: .singleton) { 
            TerminalStateHolder()
        }
    }
    
    var updateAppService: IUpdateAppService {
        resolve(scope: .singleton) {
            UpdateAppService(
                sessionService: sessionService,
                projectPathProvider: projectPathProvider,
                projectsProvider: projectsProvider
            )
        }
    }
    
    var applicationErrorHandler: IApplicationErrorHandler {
        resolve(scope: .singleton) {
            ApplicationErrorHandler(
                logger: logger,
                errorAnalytics: errorAnalytics
            )
        }
    }

    var workspaceInspectorTreeBuilder: IWorkspaceInspectorTreeBuilder {
        resolve(scope: .singleton) {
            WorkspaceInspectorTreeBuilder(workspaceMapper: workspaceMapper)
        }
    }
    
    var logRotator: ILogRotator {
        resolve(scope: .singleton) {
            LogRotator(logDirectoryProvider: logDirectoryProvider)
        }
    }

    var prepareService: IPrepareService {
        workspacePrepareService
    }
    
    var workspacePrepareService: IPrepareService {
        resolve(scope: .singleton) { 
            WorkspacePrepareService(
                projectProfilesProvider: projectProfilesProvider,
                workspaceSettingsProvider: workspaceSettingsProvider,
                cacheDurationAnalytics: cacheDurationAnalytics,
                applicationStateHolder: applicationStateHolder,
                terminalStateHolder: terminalStateHolder,
                dumpProvider: dumpProvider,
                sessionService: sessionService,
                userInfoProvider: userInfoProvider,
                configsProvider: configsProvider,
                updateAppService: updateAppService,
                logger: logger
            )
        }
    }
    
    var userInfoProvider: IUserInfoProvider {
        resolve(scope: .singleton) { 
            UserInfoProvider()
        }
    }

    var projectProfilesProvider: IProjectProfilesProvider {
        resolve(scope: .singleton) { 
            ProjectProfilesProvider(projectsProvider: projectsProvider)
        }
    }
    
    var workspaceSettingsProvider: IWorkspaceSettingsProvider {
        resolve(scope: .singleton) { 
            WorkspaceSettingsProvider()
        }
    }
    
    var workspaceMapper: IWorkspaceMapper {
        WorkspaceMapper(
            configsProvider: configsProvider,
            projectsProvider: projectsProvider
        )
    }
    
    var projectGenerationHandler: IProjectGenerationHandler {
        resolve(scope: .singleton) { 
            ProjectGenerationHandler(
                applicationStateHolder: applicationStateHolder,
                terminalStateHolder: terminalStateHolder,
                sessionService: sessionService,
                genCommandBuilder: genCommandBuilder,
                projectPathProvider: projectPathProvider,
                projectGenerationAnalytics: projectGenerationAnalytics,
                workspaceSettingsProvider: workspaceSettingsProvider,
                logger: logger
            )
        }
    }
    
    var configsProvider: IConfigsProvider {
        resolve(scope: .singleton) { 
            ConfigsProvider()
        }
    }
    
    var projectsProvider: IProjectsProvider {
        resolve(scope: .singleton) { 
            ProjectsProvider()
        }
    }
    
    var genCommandBuilder: IGenCommandBuilder {
        resolve(scope: .singleton) {
            GekoCommandBuilder(
                configProvider: configsProvider,
                projectsProvider: projectsProvider,
                profilesProvider: projectProfilesProvider
            )
        }
    }
    
    var applicationStateHandler: IApplicationStateHandler {
        resolve(scope: .singleton) { 
            ApplicationStateHandler(
                applicationStateHolder: applicationStateHolder,
                applicationErrorHandler: applicationErrorHandler,
                projectsProvider: projectsProvider,
                gitCacheProvider: gitCacheProvider,
                prepareService: prepareService
            )
        }
    }
    
    var projectPathProvider: IProjectPathProvider {
        resolve(scope: .singleton) { 
            ProjectPathProvider(pathFinderService: pathFinderService)
        }
    }
    
    
    var gitCacheProvider: IGitCacheProvider {
        resolve(scope: .singleton) { 
            GitCacheProvider(projectsProvider: projectsProvider, sessionService: sessionService, errorAnalytics: errorAnalytics)
        }
    }
    
    var dumpProvider: IDumpProvider {
        resolve(scope: .singleton) { 
            DumpProvider(sessionService: sessionService, projectsProvider: projectsProvider, pathMapper: pathMapper)
        }
    }
    
    var pathMapper: IPathMapper {
        resolve(scope: .singleton) { 
            PathMapper()
        }
    }
}

// MARK: - Analytics

private extension DependenciesAssembly {
    var logDateFormatter: ILogDateFormatter {
        resolve(scope: .singleton) { 
            LogDateFormatter()
        }
    }

    var logWritter: ILogWritter {
        resolve(scope: .singleton) { 
            LogWritter(
                logRotator: logRotator,
                logDirectoryProvider: logDirectoryProvider,
                logDateFormatter: logDateFormatter
            )
        }
    }
    var baseAnalytics: BaseAnalytics {
        resolve(scope: .singleton) { 
            BaseAnalytics(userInfoProvider: userInfoProvider, logWritter: logWritter)
        }
    }
    
    var projectSetupAnalytics: IProjectSetupAnalytics {
        resolve(scope: .singleton) { 
            ProjectSetupAnalytics(baseAnalytics: baseAnalytics)
        }
    }
    
    var projectGenerationAnalytics: IProjectGenerationAnalytics {
        resolve(scope: .singleton) { 
            ProjectGenerationAnalytics(baseAnalytics: baseAnalytics)
        }
    }
    
    var cacheDurationAnalytics: ICacheDurationAnalytics {
        resolve(scope: .singleton) {
            WorkspaceLoadDurationAnalytics(baseAnalytics: baseAnalytics)
        }
    }
    
    var errorAnalytics: IErrorAnalytics {
        resolve(scope: .singleton) { 
            ErrorAnalytics(logWritter: logWritter, userInfoProvider: userInfoProvider)
        }
    }
}
