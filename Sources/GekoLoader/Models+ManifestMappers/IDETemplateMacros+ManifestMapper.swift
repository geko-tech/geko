import Foundation
import GekoGraph
import ProjectDescription

extension FileHeaderTemplate {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        switch self {
        case let .file(path):
            let templatePath = try generatorPaths.resolve(path: path)
            self = .file(templatePath)
        case .string:
            break
        }
    }
}
