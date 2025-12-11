import Foundation
import ProjectDescription

extension ProjectDescription.PluginLocation {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        switch type {
        case let .local(path, manifest):
            self.type = .local(path: try generatorPaths.resolve(path: path), manifest: manifest)
        case .gitWithTag, .gitWithSha, .remote, .remoteGekoArchive:
            return
        }
    }
}
