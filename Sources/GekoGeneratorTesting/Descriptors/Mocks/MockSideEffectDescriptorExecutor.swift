import Foundation
import GekoCore
import GekoSupport
import ProjectDescription
@testable import GekoGenerator

final class MockSideEffectDescriptorExecutor: SideEffectDescriptorExecuting {
    var executeStub: (([SideEffectDescriptor]) throws -> Void)?
    func execute(sideEffects: [SideEffectDescriptor]) throws {
        try executeStub?(sideEffects)
    }
}
