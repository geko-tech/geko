import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport
@testable import GekoGenerator

final class MockSideEffectDescriptorExecutor: SideEffectDescriptorExecuting {
    var executeStub: (([SideEffectDescriptor]) throws -> Void)?
    func execute(sideEffects: [SideEffectDescriptor]) throws {
        try executeStub?(sideEffects)
    }
}
