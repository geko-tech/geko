import Foundation
import AppKit

enum PathFinderError: FatalError {
    case finderDidClosed
    case emptyURL
    
    var errorDescription: String? {
        switch self {
        case .finderDidClosed:
            "Finder did closed"
        case .emptyURL:
            "Empty project path"
        }
    }
    
    var type: FatalErrorType {
        .abort
    }
}

protocol IPathFinderService {
    @MainActor func projectPath() async throws -> URL 
}

final class PathFinderService: IPathFinderService {

    private let panel = NSOpenPanel()
    
    init() {
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
    }
    
    @MainActor func projectPath() async throws -> URL {
        try await handle(panel.begin())
    }
    
    private func handle(_ response: NSApplication.ModalResponse) throws -> URL {
        guard response.rawValue == 1 else {
            throw PathFinderError.finderDidClosed
        }
        guard let projectPath = panel.url else {
            throw PathFinderError.emptyURL
        }
        return projectPath
    }
}
