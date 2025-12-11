import Foundation
import TSCBasic
import Yams

enum ProjectProfilesState {
    case loaded([ProjectProfile])
    case error
    case empty
}

protocol IProjectProfilesProvider {
    var profilesState: ProjectProfilesState { get }

    @discardableResult
    func loadProfiles() throws -> [ProjectProfile]
}

final class ProjectProfilesProvider: IProjectProfilesProvider {
    
    var profilesState: ProjectProfilesState = .empty
    
    private let projectsProvider: IProjectsProvider
    
    init(projectsProvider: IProjectsProvider) {
        self.projectsProvider = projectsProvider
    }

    @discardableResult
    func loadProfiles() throws -> [ProjectProfile] {
        guard let path = projectsProvider.selectedProject()?.clearPath() else {
            throw GlobalError.projectNotSelected
        }
        do {
            let profilesFilePath = path
                .appending(component: Constants.gekoDirectoryName)
                .appending(component: Constants.projectProfilesFileName)

            guard FileManager.default.fileExists(atPath: profilesFilePath.pathString) else {
                throw GlobalError.fileNotFound(fileName: Constants.projectProfilesFileName)
            }
            let decoder = YAMLDecoder()
            let data = try Data(contentsOf: profilesFilePath.asURL)

            let rawProfiles: [String: [String: String]] = try decoder.decode(from: data)
            let profiles = rawProfiles.map { ProjectProfile(name: $0.key, options: $0.value) }
            profilesState = .loaded(profiles)
            return profiles
        } catch {
            profilesState = .error
            throw error
        }
    }
}
