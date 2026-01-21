import Foundation
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
import XcodeProj
@testable import GekoGenerator

final class MockWorkspaceDescriptorGenerator: WorkspaceDescriptorGenerating {
    enum MockError: Error {
        case stubNotImplemented
    }

    var generateWorkspaces: [Workspace] = []
    var generateStub: ((GraphTraversing) throws -> WorkspaceDescriptor)?

    func generate(graphTraverser: GraphTraversing) throws -> WorkspaceDescriptor {
        guard let generateStub else {
            throw MockError.stubNotImplemented
        }
        generateWorkspaces.append(graphTraverser.workspace)
        return try generateStub(graphTraverser)
    }
}
