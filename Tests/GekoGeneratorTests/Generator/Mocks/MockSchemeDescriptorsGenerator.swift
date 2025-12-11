import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoGraphTesting
@testable import GekoGenerator

final class MockSchemeDescriptorsGenerator: SchemeDescriptorsGenerating {
    func generateProjectSchemes(
        project _: Project,
        generatedProject _: GeneratedProject,
        graphTraverser _: GraphTraversing
    ) throws -> [SchemeDescriptor] {
        []
    }

    func generateWorkspaceSchemes(
        workspace _: Workspace,
        generatedProjects _: [AbsolutePath: GeneratedProject],
        graphTraverser _: GraphTraversing
    ) throws -> [SchemeDescriptor] {
        []
    }
}
