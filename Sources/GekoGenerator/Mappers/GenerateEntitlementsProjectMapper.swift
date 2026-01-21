import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import XcodeProj
import ProjectDescription

/// A project mapper that generates derived entitlements files for targets that define it as a dictonary.
public final class GenerateEntitlementsProjectMapper: ProjectMapping {
    private let derivedDirectoryName: String
    private let entitlementsDirectoryName: String

    public init(
        derivedDirectoryName: String = Constants.DerivedDirectory.name,
        entitlementsDirectoryName: String = Constants.DerivedDirectory.entitlements
    ) {
        self.derivedDirectoryName = derivedDirectoryName
        self.entitlementsDirectoryName = entitlementsDirectoryName
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
                projectPath: project.path
            )
            sideEffects.append(contentsOf: targetSideEffects)
        }

        return sideEffects
    }

    // MARK: - Private

    private func map(target: inout Target, projectPath: AbsolutePath) throws -> [SideEffectDescriptor] {
        // There's nothing to do
        guard let entitlements = target.entitlements else {
            return []
        }

        // Get the entitlements that needs to be generated
        guard let dictionary = entitlementsDictionary(
            entitlements: entitlements
        )
        else {
            return []
        }
        let data = try PropertyListSerialization.data(
            fromPropertyList: dictionary,
            format: .xml,
            options: 0
        )

        let entitlementsPath = projectPath
            .appending(component: derivedDirectoryName)
            .appending(component: Constants.DerivedDirectory.entitlements)
            .appending(component: "\(target.name).entitlements")
        let sideEffect = SideEffectDescriptor.file(FileDescriptor(path: entitlementsPath, contents: data))

        target.entitlements = Entitlements.generatedFile(path: entitlementsPath, data: data)

        return [sideEffect]
    }

    private func entitlementsDictionary(
        entitlements: Entitlements
    ) -> [String: Any]? {
        switch entitlements {
        case let .dictionary(content):
            return content.mapValues { $0.value }
        default:
            return nil
        }
    }
}
