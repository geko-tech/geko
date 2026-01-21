import Foundation
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
import XcodeProj
@testable import GekoGenerator

final class MockProjectDescriptorGenerator: ProjectDescriptorGenerating {
    enum MockError: Error {
        case stubNotImplemented
    }

    var generatedProjects: [Project] = []
    var generateStub: ((Project, GraphTraversing) throws -> ProjectDescriptor)?

    func generate(project: Project, graphTraverser: GekoCore.GraphTraversing, verbose: Bool) throws -> GekoGenerator.ProjectDescriptor {
        guard let generateStub else {
            throw MockError.stubNotImplemented
        }
        generatedProjects.append(project)
        return try generateStub(project, graphTraverser)
    }
}
