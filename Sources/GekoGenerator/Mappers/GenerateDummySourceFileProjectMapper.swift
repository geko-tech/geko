import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class GenerateDummySourceFileProjectMapper: ProjectMapping {
    private let derivedDirectoryName: String
    private let sourcesDirectoryName: String

    public init(
        derivedDirectoryName: String = Constants.DerivedDirectory.name,
        sourcesDirectoryName: String = Constants.DerivedDirectory.sources
    ) {
        self.derivedDirectoryName = derivedDirectoryName
        self.sourcesDirectoryName = sourcesDirectoryName
    }

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        let sourcesPath = project.path
            .appending(component: derivedDirectoryName)
            .appending(component: sourcesDirectoryName)

        var sideEffects: [SideEffectDescriptor] = []

        for t in 0..<project.targets.count {
            guard project.targets[t].sources.isEmpty,
                project.targets[t].buildableFolders.isEmpty,
                project.targets[t].supportsSources
            else {
                continue
            }

            let (dummyFileDescriptor, dummyFilePath) = generateDummyFile(
                withName: project.targets[t].name + "Dummy",
                path: sourcesPath
            )

            project.targets[t].sources = [SourceFiles(paths: [dummyFilePath])]

            sideEffects.append(dummyFileDescriptor)
        }

        return sideEffects
    }

    private func generateDummyFile(
        withName name: String,
        path: AbsolutePath
    ) -> (SideEffectDescriptor, AbsolutePath) {
        let fileContent = """
            import Foundation
            final class DummyClass {}
            """

        let filePath = path.appending(component: name + ".swift")

        return (
            .file(
                .init(
                    path: filePath,
                    contents: fileContent.data(using: .utf8),
                    state: .present
                )
            ),
            filePath
        )
    }
}
