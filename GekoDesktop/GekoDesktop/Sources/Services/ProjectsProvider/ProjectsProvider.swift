import Foundation
import TSCBasic

struct UserProject: Codable, Hashable {
    let name: String
    let path: AbsolutePath
    
    func clearPath() -> AbsolutePath {
        AbsolutePath(stringLiteral: path.pathString.replacingOccurrences(of: "file://", with: ""))
    }
}

protocol IProjectsProviderDelegate: AnyObject {
    func selectedProjectDidChanged(_ project: UserProject)
    func allProjectsDidChanged(_ projects: [UserProject])
}

extension IProjectsProviderDelegate {
    func selectedProjectDidChanged(_ project: UserProject) {}
    func allProjectsDidChanged(_ projects: [UserProject]) {}
}

protocol IProjectsProvider {
    @discardableResult
    func addProject(path: AbsolutePath) -> UserProject
    func deleteProject(name: String)
    func allProjects() -> [UserProject]
    func selectProject(name: String)
    func selectedProject() -> UserProject?
    func clear()
    
    func addSubscription(_ subscription: some IProjectsProviderDelegate)
}

final class ProjectsProvider: IProjectsProvider {
    enum Keys: String {
        case userProjects
        case selectedProjects
    }
    
    private let ud = UserDefaults()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var subscriptions = DelegatesList<IProjectsProviderDelegate>()
    private var projectsCache: [UserProject] = []
    
    init() {
        if let rawProjects = ud.array(forKey: Keys.userProjects.rawValue) as? [Data] {
            projectsCache = rawProjects.compactMap { try? decoder.decode(UserProject.self, from: $0)
            }
        } else {
            projectsCache = []
        }
    }
    
    func addSubscription(_ subscription: some IProjectsProviderDelegate) {
        subscriptions.addDelegate(weakify(subscription))
    }

    func addProject(path: TSCBasic.AbsolutePath) -> UserProject {
        let project = UserProject(name: name(from: path), path: path)
        projectsCache.append(project)
        ud.set(projectsCache.compactMap { try? encoder.encode($0) }, forKey: Keys.userProjects.rawValue)
        subscriptions.forEach { $0.allProjectsDidChanged(projectsCache) }
        return project
    }
    
    func deleteProject(name: String) {
        projectsCache = projectsCache.filter { $0.name != name}
        ud.set(projectsCache.compactMap { try? encoder.encode($0) }, forKey: Keys.userProjects.rawValue)
        subscriptions.forEach { $0.allProjectsDidChanged(projectsCache) }
    }
    
    func allProjects() -> [UserProject] {
        projectsCache
    }
    
    func selectProject(name: String) {
        ud.set(name, forKey: Keys.selectedProjects.rawValue)
        if let project = projectsCache.first(where: { $0.name == name }) {
            FileManager.default.changeCurrentDirectoryPath(project.clearPath().pathString)
            subscriptions.forEach { $0.selectedProjectDidChanged(project)}
        }
    }
    
    func selectedProject() -> UserProject? {
        guard let name = ud.string(forKey: Keys.selectedProjects.rawValue) else {
            return nil
        }
        return projectsCache.first(where: { $0.name == name })
    }
    
    func clear() {
        projectsCache = []
        ud.removeObject(forKey: Keys.userProjects.rawValue)
        ud.removeObject(forKey: Keys.selectedProjects.rawValue)
        subscriptions.forEach { $0.allProjectsDidChanged(projectsCache) }
    }
    
    private func name(from path: AbsolutePath) -> String {
        guard let lastPart = path.components.last else {
            return path.pathString
        }
        let name = lastPart
        let allNames = projectsCache.map { $0.name }
        if !allNames.contains(name) {
            return name
        }
        
        for i in (1...100) {
            let newName = "\(name)-\(i)"
            if !allNames.contains(newName) {
                return newName
            }
        }
        return path.pathString
    }
}
