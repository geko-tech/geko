import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// A workspace mapper that returns side effects to delete the derived directory.
public final class DeleteDerivedDirectoryWorkspaceMapper: WorkspaceMapping {
    private let derivedDirectoryName: String
    private let fileHandler: FileHandling

    public init(
        derivedDirectoryName: String = Constants.DerivedDirectory.name,
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.derivedDirectoryName = derivedDirectoryName
        self.fileHandler = fileHandler
    }

    // MARK: - ProjectMapping

    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable
    ) throws -> [SideEffectDescriptor] {
        var sideEffects: [SideEffectDescriptor] = []
        
        for i in 0 ..< workspace.projects.count {
            let project = workspace.projects[i]

            let projectSideEffects = try sideEffectDescriptors(for: project)

            sideEffects.append(contentsOf: projectSideEffects)
        }
        
        return sideEffects
    }

    private func sideEffectDescriptors(for project: Project) throws -> [SideEffectDescriptor] {
        logger.debug("Determining the /Derived directories that should be deleted within \(project.path)")
        let derivedDirectoryPath = project.path.appending(component: derivedDirectoryName)
        
        guard fileHandler.exists(derivedDirectoryPath) else {
            return []
        }
        
        // FIXME: Currently, the behavior for local spm packages differs from remote ones.
        // It would be great to either put all derived local packages into geko-derived or come up with a more elegant solution.
        if project.projectType == .spm {
            return try fileHandler.contentsOfDirectory(derivedDirectoryPath)
                .filter { $0.extension != "modulemap" }
                .map {
                    if fileHandler.isFolder($0) {
                        return .directory(DirectoryDescriptor(path: $0, state: .absent))
                    } else {
                        return .file(FileDescriptor(path: $0, state: .absent))
                    }
                }
        } else {
            return [.directory(DirectoryDescriptor(path: derivedDirectoryPath, state: .absent))]
        }
    }
}
