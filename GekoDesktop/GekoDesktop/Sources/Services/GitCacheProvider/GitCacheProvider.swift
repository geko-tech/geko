import Foundation
import TSCBasic

enum GitEvent {
    case pull
    case checkout(branch: String)
    case error(_ error: Error)
}

protocol IGitCacheProviderDelegate: AnyObject {
    func event(_ gitEvent: GitEvent)
}

protocol IGitCacheProvider {
    func needReload() -> Bool
    func observe()
    
    func addSubscription(_ subscription: some IGitCacheProviderDelegate)
}

final class GitCacheProvider: IGitCacheProvider {
    
    private let projectsProvider: IProjectsProvider
    private let sessionService: ISessionService
    private let errorAnalytics: IErrorAnalytics
    private let fileManager = FileManager.default
    private let ud = UserDefaults()
    
    private var subscriptions = DelegatesList<IGitCacheProviderDelegate>()

    private var fileHandle: FileHandle? = nil
    private var source: DispatchSourceFileSystemObject? = nil
    
    init(
        projectsProvider: IProjectsProvider,
        sessionService: ISessionService,
        errorAnalytics: IErrorAnalytics
    ) {
        self.projectsProvider = projectsProvider
        self.sessionService = sessionService
        self.errorAnalytics = errorAnalytics
        
        projectsProvider.addSubscription(self)
    }
    
    func needReload() -> Bool {
        let lastCommit = lastCommit()
        let currentCommit = currentCommit()
        updateLastCommit(currentCommit)
        return lastCommit != currentCommit
    }
    
    func observe() {
        guard let selectedProject = projectsProvider.selectedProject(), let headFilePath = logHeadFilePath(for: selectedProject) else {
            return
        }
        setup(for: AbsolutePath(url: headFilePath))
    }
    
    func addSubscription(_ subscription: some IGitCacheProviderDelegate) {
        subscriptions.addDelegate(weakify(subscription))
    }
    
    private func currentCommit() -> String {
        switch try? sessionService.exec(ShellCommand(arguments: ["git rev-parse HEAD"])) {
        case .collected(let data):
            String(data: data, encoding: .utf8)?.removeNewLines() ?? ""
        default:
            ""
        }
    }
    
    private func lastCommit() -> String {
        guard let project = projectsProvider.selectedProject() else {
            return ""
        }
        return ud.string(forKey: projectKey(project)) ?? ""
    }
    
    private func updateLastCommit(_ commit: String) {
        guard let project = projectsProvider.selectedProject() else {
            return
        }
        ud.set(commit, forKey: projectKey(project))
    }
    
    private func logHeadFilePath(for project: UserProject) -> URL? {
        let gitDir = project.clearPath().appending(components: [".git", "logs", "HEAD"])
        let gitFile = project.clearPath().appending(component: ".git")
        if fileManager.fileExists(atPath: gitDir.pathString) {
            return gitDir.asURL
        } else if fileManager.fileExists(atPath: gitFile.pathString) {
            let dirPath = try? String(contentsOf: gitFile.asURL, encoding: .utf8).removeNewLines().replacingOccurrences(of: "gitdir: ", with: "")
            if let dirPath {
                return fileManager.fileExists(atPath: "\(dirPath)/logs/HEAD") ? URL(string: "\(dirPath)/logs/HEAD") : nil
            } else {
                return nil
            }
        }
        return nil
    }
    
    private func projectKey(_ project: UserProject) -> String {
        "lastCommit\(project.clearPath().pathString)"
    }
    
    private func setup(for path: AbsolutePath) {
        do {
            let fileHandle = try FileHandle(forReadingFrom: path.asURL)
            self.fileHandle = fileHandle
            source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileHandle.fileDescriptor,
                eventMask: .all,
                queue: DispatchQueue.main
            )
            source?.setEventHandler {
                guard let event = self.source?.data else {
                    return
                }
                self.handle(event: event, for: path)
            }
            self.fileHandle?.seekToEndOfFile()
            source?.activate()
        } catch {
            if !ApplicationSettingsService.shared.gitObserverDisabled {
                errorAnalytics.error(error)
            }
        }
    }
    
    private func handle(event: DispatchSource.FileSystemEvent, for path: AbsolutePath) {
        defer {
            /// After changing a file, its handler changes, and it needs to be retrieved again and the listener started.
            /// also need to subscribe to the change of projectInfoProvider when the project folder changes
            setup(for: path)
        }
        guard
            let newData = fileHandle?.readDataToEndOfFile(),
            let string = String(data: newData, encoding: .utf8)
        else {
            return
        }
        guard let response = parseResponse(string) else {
            return
        }
        let currentCommit = currentCommit()
        let lastCommit = lastCommit()
        if currentCommit != lastCommit, !ApplicationSettingsService.shared.gitObserverDisabled {
            updateLastCommit(currentCommit)
            subscriptions.makeIterator().forEach {
                $0.event(response)
            }
        }
    }
    
    private func parseResponse(_ str: String) -> GitEvent? {
        guard let info = str.split(separator: "\t").last else {
            return nil
        }
        let infoStr = String(info)
        if infoStr.hasPrefix("checkout:"), let branch = infoStr.branch {
            return .checkout(branch: branch.removeNewLines())
        } else if infoStr.hasPrefix("pull") {
            return .pull
        } else {
            return nil
        }
    }
}

extension GitCacheProvider: IProjectsProviderDelegate {
    func selectedProjectDidChanged(_ project: UserProject) {
        if let logfilePath = logHeadFilePath(for: project) {
            setup(for: AbsolutePath(url: logfilePath))
        }
    }
}
