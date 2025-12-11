import Combine
import Foundation

protocol IProjectGenerationHandler {
    func generate() throws
    func stopGenerate()
}

final class ProjectGenerationHandler: IProjectGenerationHandler {
    
    private let applicationStateHolder: IApplicationStateHolder
    private let terminalStateHolder: ITerminalStateHolder
    private let sessionService: ISessionService
    private let genCommandBuilder: IGenCommandBuilder
    private let projectPathProvider: IProjectPathProvider
    private let projectGenerationAnalytics: IProjectGenerationAnalytics
    private let workspaceSettingsProvider: IWorkspaceSettingsProvider
    private let logger: ILogger
    
    private var buffer = Data()
    private var generationStartTime = CFAbsoluteTimeGetCurrent()
    
    private var bag = Set<AnyCancellable>()
    
    init(
        applicationStateHolder: IApplicationStateHolder,
        terminalStateHolder: ITerminalStateHolder,
        sessionService: ISessionService,
        genCommandBuilder: IGenCommandBuilder,
        projectPathProvider: IProjectPathProvider,
        projectGenerationAnalytics: IProjectGenerationAnalytics,
        workspaceSettingsProvider: IWorkspaceSettingsProvider,
        logger: ILogger
    ) {
        self.applicationStateHolder = applicationStateHolder
        self.terminalStateHolder = terminalStateHolder
        self.sessionService = sessionService
        self.genCommandBuilder = genCommandBuilder
        self.projectPathProvider = projectPathProvider
        self.projectGenerationAnalytics = projectGenerationAnalytics
        self.workspaceSettingsProvider = workspaceSettingsProvider
        self.logger = logger
    }
    
    func generate() throws {
        guard applicationStateHolder.executionState == .idle else {
            return
        }
        Task {
            await applicationStateHolder.changeExecutionState(.executing)
            await terminalStateHolder.changeTerminalState(true)
            await terminalStateHolder.resetSession()
            try generateProject()
        }
    }
    
    func stopGenerate() {
        guard applicationStateHolder.executionState == .executing else {
            return
        }
        bag.forEach { $0.cancel() }
        send(.warning, message: "Generation cancelled\r\n", newState: .idle)
    }
}

// MARK: - Fetch

private extension ProjectGenerationHandler {
    func handleCompletion(_ completion: Combine.Subscribers.Completion<Error>) {
        switch completion {
        case .finished:
            handleSuccess()
        case .failure(let failure):
            handleError(failure)
        }
    }
    
    func generateProject() throws {
        generationStartTime = CFAbsoluteTimeGetCurrent()
        let commands = genCommandBuilder.buildGenCommand()
        switch try sessionService.exec(ShellCommand(arguments: commands, resultType: .stream)) {
        case .stream(let publisher):
            publisher.sink { completion in
                self.handleCompletion(completion)
            } receiveValue: { _ in }.store(in: &bag)
        default: throw ResponseTypeError.wrongType
        }
    }
    
    func handleError(_ error: Error) {
        changeState(.idle)
        let delta = CFAbsoluteTimeGetCurrent() - generationStartTime
        projectGenerationAnalytics.generationDidFinished(generationFinishedType: .failure, duration: delta.formatted())
    }
    
    func handleSuccess() {
        changeState(.idle)
        let delta = CFAbsoluteTimeGetCurrent() - generationStartTime
        projectGenerationAnalytics.generationDidFinished(generationFinishedType: .success, duration: delta.formatted())
    }
}

private extension ProjectGenerationHandler {
    func send(_ logLevel: LogLevel, message: String, newState: AppState? = nil) {
        Task {
            logger.log(logLevel, info: message)
            if newState != nil {
                await applicationStateHolder.changeExecutionState(.idle)
            }
        }
    }
    
    func changeState(_ newState: AppState) {
        Task {
            await applicationStateHolder.changeExecutionState(.idle)
        }
    }
    
    private func command(_ string: String) -> String {
        var tmpStr = string
        for symbols in symbolsToReplace {
            tmpStr.replace(symbols, with: "\n")
        }
        return tmpStr.split(separator: "\n")
            .map { String($0) }
            .map { $0.removeNewLines().addNewLine() }
            .joined()
    }
    
    private var symbolsToReplace: Set<String> {
        ["\u{1B}[2K"]
    }
}
