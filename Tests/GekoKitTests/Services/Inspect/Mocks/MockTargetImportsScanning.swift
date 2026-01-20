import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription
@testable import GekoKit

final class MockTargetImportsScanner: TargetImportsScanning {
    var invokedImports = false
    var stubbedImportsResult: [Target: Set<String>] = [:]
    func imports(for target: Target, sideEffects: [SideEffectDescriptor]) async throws -> Set<String> {
        invokedImports = true
        return stubbedImportsResult[target] ?? []
    }
}
