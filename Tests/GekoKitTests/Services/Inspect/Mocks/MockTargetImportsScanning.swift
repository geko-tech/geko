import Foundation
import GekoGraph
import GekoSupport
@testable import GekoKit

final class MockTargetImportsScanner: TargetImportsScanning {
    var invokedImports = false
    var stubbedImportsResult: [GekoGraph.Target: Set<String>] = [:]
    func imports(for target: GekoGraph.Target, sideEffects: [SideEffectDescriptor]) async throws -> Set<String> {
        invokedImports = true
        return stubbedImportsResult[target] ?? []
    }
}
