import Foundation
import GekoSupport

public final class MockCIChecker: CIChecking {
    var isCIStub: Bool = false

    public init() {}
    
    public func isCI() -> Bool {
        isCIStub
    }
}
