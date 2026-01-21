import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription
import XcodeProj

/// A project mapper that generates derived Info.plist files for targets that define it as a dictonary.
public final class GenerateInfoPlistProjectMapper: ProjectMapping {
    private let infoPlistContentProvider: InfoPlistContentProviding
    private let derivedDirectoryName: String
    private let infoPlistsDirectoryName: String

    public convenience init(
        derivedDirectoryName: String = Constants.DerivedDirectory.name,
        infoPlistsDirectoryName: String = Constants.DerivedDirectory.infoPlists
    ) {
        self.init(
            infoPlistContentProvider: InfoPlistContentProvider(),
            derivedDirectoryName: derivedDirectoryName,
            infoPlistsDirectoryName: infoPlistsDirectoryName
        )
    }

    init(
        infoPlistContentProvider: InfoPlistContentProviding,
        derivedDirectoryName: String,
        infoPlistsDirectoryName: String
    ) {
        self.infoPlistContentProvider = infoPlistContentProvider
        self.derivedDirectoryName = derivedDirectoryName
        self.infoPlistsDirectoryName = infoPlistsDirectoryName
    }

    // MARK: - ProjectMapping

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        var sideEffects: [SideEffectDescriptor] = []

        for i in 0 ..< project.targets.count {
            let targetSideEffects = try map(
                target: &project.targets[i],
                project: project
            )
            sideEffects.append(contentsOf: targetSideEffects)
        }

        return sideEffects
    }

    // MARK: - Private

    private func map(target: inout Target, project: Project) throws -> [SideEffectDescriptor] {
        // There's nothing to do
        guard let infoPlist = target.infoPlist else {
            return []
        }

        switch infoPlist {
        case let .generatedFile(path, data):
            let sideEffect = SideEffectDescriptor.file(FileDescriptor(path: path, contents: data))
            return [sideEffect]
        case .extendingDefault(_), .dictionary(_), .file(_):
            guard let dictionary = infoPlistDictionary(
                infoPlist: infoPlist,
                project: project,
                target: target
            )
            else {
                return []
            }
            let data = try PropertyListSerialization.data(
                fromPropertyList: dictionary,
                format: .xml,
                options: 0
            )

            let infoPlistPath = project.derivedDirectoryPath(for: target.name)
                .appending(component: infoPlistsDirectoryName)
                .appending(component: "\(target.name)-Info.plist")

            let sideEffect = SideEffectDescriptor.file(FileDescriptor(path: infoPlistPath, contents: data))
            target.infoPlist = InfoPlist.generatedFile(path: infoPlistPath, data: data)
            return [sideEffect]
        }
    }

    private func infoPlistDictionary(
        infoPlist: InfoPlist,
        project: Project,
        target: Target
    ) -> [String: Any]? {
        switch infoPlist {
        case let .dictionary(content):
            return content.mapValues { $0.value }
        case let .extendingDefault(extended):
            if let content = infoPlistContentProvider.content(
                project: project,
                target: target,
                extendedWith: extended
            ) {
                return content
            }
            return nil
        case .file(_), .generatedFile(_, _):
            return nil
        }
    }
}
