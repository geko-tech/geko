import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension ConfigurationSettings {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        xcconfig = try xcconfig.map { try generatorPaths.resolve(path: $0) }
    }
}
