import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription
import XcodeProj

enum BuildableFolderGenerationError: FatalError, Equatable {
    case missingFileReference(AbsolutePath, String)

    var description: String {
        switch self {
        case let .missingFileReference(path, targetName):
            return "Trying to add buildable folder at path \(path.pathString) to a build phase that hasn't been added to the project. \(targetName)"
        }
    }

    var type: ErrorType {
        switch self {
        case .missingFileReference:
            return .bug
        }
    }
}

protocol BuildableFolderGenerating: AnyObject {
    func generateBuildableFolders(
        project: Project,
        pbxproj: PBXProj,
        pbxProject: PBXProject,
        fileElements: ProjectFileElements
    ) throws
}

// swiftlint:disable:next type_body_length
final class BuildableFolderGenerator: BuildableFolderGenerating {
    func generateBuildableFolders(
        project: Project,
        pbxproj: PBXProj,
        pbxProject: PBXProject,
        fileElements: ProjectFileElements
    ) throws {
        for target in project.targets {
            for buildableFolder in target.buildableFolders {
                let pbxtargets = pbxproj.targets(named: target.name)

                guard pbxtargets.count == 1 else {
                    fatalError("expected 1 pbxtarget")
                }

                try addBuildableFolder(
                    buildableFolder,
                    target: target,
                    pbxTarget: pbxtargets[0],
                    fileElements: fileElements,
                    pbxproj: pbxproj
                )
            }
        }
    }

    private func addBuildableFolder(
        _ folder: BuildableFolder,
        target: Target,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj,
        fileHandler: FileHandling = FileHandler.shared
    ) throws {
        guard let synchronizedRootGroup = fileElements.buildableFolder(path: folder.path) else {
            throw BuildableFolderGenerationError.missingFileReference(folder.path, target.name)
        }

        if !folder.exceptions.isEmpty {
            var explicitFolders: [AbsolutePath] = []

            for exception in folder.exceptions {
                if fileHandler.isFolder(exception) {
                    explicitFolders.append(exception)
                }
            }

            let fileExceptionSet = PBXFileSystemSynchronizedBuildFileExceptionSet(
                target: pbxTarget,
                membershipExceptions: folder
                    .exceptions
                    .map { $0.relative(to: folder.path).pathString }
                    .sorted(),
                publicHeaders: nil,
                privateHeaders: nil,
                additionalCompilerFlagsByRelativePath: nil,
                attributesByRelativePath: nil
            )
            pbxproj.add(object: fileExceptionSet)
            synchronizedRootGroup.exceptions = (synchronizedRootGroup.exceptions ?? []) + [fileExceptionSet]
            if !explicitFolders.isEmpty {
                synchronizedRootGroup.explicitFolders =
                    (synchronizedRootGroup.explicitFolders ?? [])
                    + explicitFolders.map { $0.relative(to: folder.path).pathString }.sorted()
            }
        }

        pbxTarget.fileSystemSynchronizedGroups = (pbxTarget.fileSystemSynchronizedGroups ?? []) + [synchronizedRootGroup]
    }
}
