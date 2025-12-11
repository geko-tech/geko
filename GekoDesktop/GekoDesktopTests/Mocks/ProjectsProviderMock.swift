import TSCBasic
@testable import GekoDesktop

final class ProjectsProviderMock: IProjectsProvider {
    
    var projects: [String: UserProject] = [:]
    var project: UserProject?
    
    func addProject(path: TSCBasic.AbsolutePath) -> GekoDesktop.UserProject {
        let name = path.basenameWithoutExt
        let proj = UserProject(name: name, path: path)
        projects[name] = proj
        return proj
    }
    
    func deleteProject(name: String) {
        projects.removeValue(forKey: name)
    }
    
    func allProjects() -> [GekoDesktop.UserProject] {
        projects.map { $0.value }
    }
    
    func selectProject(name: String) {
        if let proj = projects.first(where: { $0.key == name }) {
            project = proj.value
        }
    }
    
    func selectedProject() -> GekoDesktop.UserProject? {
        project
    }
    
    func clear() {
        projects = [:]
    }
    
    func addSubscription(_ subscription: some GekoDesktop.IProjectsProviderDelegate) {}
}
