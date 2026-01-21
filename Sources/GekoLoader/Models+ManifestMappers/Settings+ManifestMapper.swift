import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

extension Settings {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        for key in configurations.keys {
            guard let settings = configurations[key], var settings = settings else { continue }
            settings.xcconfig = try settings.xcconfig.map { try generatorPaths.resolve(path: $0) }
            configurations[key] = settings
        }
    }
}
