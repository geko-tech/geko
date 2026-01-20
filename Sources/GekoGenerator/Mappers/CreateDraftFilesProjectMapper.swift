import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class CreateDraftFilesProjectMapper: ProjectMapping {
    public init() {}

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        var descriptors: [SideEffectDescriptor] = []

        let projectPath = project.path

        for targetIdx in 0..<project.targets.count {
            guard !project.targets[targetIdx].preCreatedFiles.isEmpty else {
                continue
            }

            var targetSourceFiles: [AbsolutePath] = []

            for file in project.targets[targetIdx].preCreatedFiles {
                let relativePath = try RelativePath(validatingRelativePath: file)
                let absolutePath = projectPath.appending(relativePath)

                if absolutePath.extension == nil {
                    descriptors.append(.directory(
                        .init(path: absolutePath, state: .present)
                    ))
                    continue
                }

                targetSourceFiles.append(absolutePath)

                descriptors.append(.file(
                    .init(path: absolutePath, state: .present)
                ))
            }

            project.targets[targetIdx].sources.append(SourceFiles(paths: targetSourceFiles))
        }

        return descriptors
    }
}
