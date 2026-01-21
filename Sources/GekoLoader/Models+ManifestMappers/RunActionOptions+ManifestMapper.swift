import Foundation
import GekoGraph
import ProjectDescription

extension RunActionOptions {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        self.storeKitConfigurationPath = try storeKitConfigurationPath.map {
            try generatorPaths.resolveSchemeActionProjectPath($0)
        }
        try simulatedLocation?.resolvePaths(generatorPaths: generatorPaths)
    }
}

extension RunActionOptions.SimulatedLocation {
    mutating func resolvePaths(generatorPaths: GeneratorPaths) throws {
        switch self {
        case .reference:
            break
        case let .gpxFile(gpxFilePath):
           self = .gpxFile(try generatorPaths.resolveSchemeActionProjectPath(gpxFilePath))
        }
    }
}
