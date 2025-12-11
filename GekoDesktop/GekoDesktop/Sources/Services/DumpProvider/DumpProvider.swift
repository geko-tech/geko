import Foundation
import struct ProjectDescription.Config

protocol IDumpProvider {
    func dumpGraph(_ project: UserProject, profileName: String?) throws -> GraphDump
    func parseGraph(_ project: UserProject) throws -> GraphDump
    func graphExist(_ project: UserProject) -> Bool

    func dumpConfig(_ project: UserProject) throws -> Config
    func parseConfig(_ project: UserProject) throws -> Config
    func configExist(_ project: UserProject) -> Bool
}

final class DumpProvider: IDumpProvider {

    private let sessionService: ISessionService
    private let projectsProvider: IProjectsProvider
    private let pathMapper: IPathMapper
    private let decoder = JSONDecoder()
    private let fileHandler = FileManager.default
    
    init(sessionService: ISessionService, projectsProvider: IProjectsProvider, pathMapper: IPathMapper) {
        self.sessionService = sessionService
        self.projectsProvider = projectsProvider
        self.pathMapper = pathMapper
    }
    
    func dumpGraph(_ project: UserProject, profileName: String?) throws -> GraphDump {
        let filePath = CacheDir.projectDir(project.name)
        try? fileHandler.removeItem(atPath: filePath.appending(component: Constants.gekoGraphFileName).pathString)
        try sessionService.exec("geko fetch -r && geko graph --format json -o \(filePath)")
        return try parseGraph(project)
    }
    
    func parseGraph(_ project: UserProject) throws -> GraphDump {
        let filePath = CacheDir.projectDir(project.name).appending(component: Constants.gekoGraphFileName)
        guard FileManager.default.fileExists(atPath: filePath.pathString) else {
            throw GlobalError.fileNotFound(fileName: Constants.gekoGraphFileName)
        }
        do {
            let data = try Data(contentsOf: filePath.asURL)
            let graph = try decoder.decode(GraphDump.self, from: data)
            return graph
        } catch let decodingError as DecodingError {
            throw GlobalError.from(decodingError: decodingError, entity: GraphDump.self)
        } catch {
            throw error
        }
    }
    
    func graphExist(_ project: UserProject) -> Bool {
        fileHandler.fileExists(atPath: CacheDir.projectDir(project.name).appending(component: Constants.gekoGraphFileName).pathString)
    }
    
    func dumpConfig(_ project: UserProject) throws -> Config {
        let filePath = CacheDir.projectDir(project.name).appending(component: Constants.gekoConfigFileName)
        try? fileHandler.removeItem(atPath: filePath.pathString)
        do {
            try sessionService.exec(ShellCommand(silence: true, arguments: ["geko dump config -r \(filePath)"]))
            return try parseConfig(project)
        }
    }
    
    func parseConfig(_ project: UserProject) throws -> Config {
        let filePath = CacheDir.projectDir(project.name).appending(component: Constants.gekoConfigFileName)
        guard FileManager.default.fileExists(atPath: filePath.pathString) else {
            throw GlobalError.fileNotFound(fileName: Constants.gekoConfigFileName)
        }
        do {
            let data = try Data(contentsOf: filePath.asURL)
            return try decoder.decode(Config.self, from: data)
        } catch let decodingError as DecodingError {
            throw GlobalError.from(decodingError: decodingError, entity: Config.self)
        } catch {
            throw error
        }
    }
    
    func configExist(_ project: UserProject) -> Bool {
        fileHandler.fileExists(atPath: CacheDir.projectDir(project.name).appending(component: Constants.gekoConfigFileName).pathString)
    }
}


