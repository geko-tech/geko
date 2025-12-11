import Foundation
import TSCBasic

enum ProjectPathError: FatalError {
    case wrongPath
    
    var errorDescription: String? {
        switch self {
        case .wrongPath:
            "This project not support Geko"
        }
    }
    
    var type: FatalErrorType {
        .abort
    }
}

protocol IProjectPathProvider {
    func selectProjectPath() async throws -> AbsolutePath?
}

final class ProjectPathProvider: IProjectPathProvider {
    
    private let pathFinderService: IPathFinderService
    
    init(pathFinderService: IPathFinderService) {
        self.pathFinderService = pathFinderService
    }
    
    func selectProjectPath() async throws -> AbsolutePath? {
        do {
            let url = try await pathFinderService.projectPath()
            let absolutePath = AbsolutePath(url: url)
            if !isValidFolder(absolutePath) {
                throw ProjectPathError.wrongPath
            }
            return absolutePath
        } catch PathFinderError.finderDidClosed {
            return nil
        } catch {
            throw error
        }
    }
    
    private func isValidFolder(_ path: AbsolutePath) -> Bool {
        FileManager.default.fileExists(atPath: "\(path.pathString)/Geko")
    }
}
