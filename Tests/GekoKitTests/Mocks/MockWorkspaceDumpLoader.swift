import Foundation
import GekoKit
import struct ProjectDescription.AbsolutePath
import GekoLoader
import GekoGraph
import ProjectDescription

final class MockWorkspaceDumpLoader: WorkspaceDumpLoading {
    var stubbedWorkspace: GekoKit.WorkspaceDump!

    func load(path: AbsolutePath) async throws -> GekoKit.WorkspaceDump {
        stubbedWorkspace
    }
}
