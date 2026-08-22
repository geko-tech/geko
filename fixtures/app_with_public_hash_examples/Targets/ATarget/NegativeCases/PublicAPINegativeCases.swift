import Foundation

// Expected: Ignore
private struct NegativePrivateTopLevelType {
    let value: Int
}

// Expected: Ignore
struct NegativeInternalTopLevelType {
    let value: Int
}

// Expected: Ignore
private func negativePrivateTopLevelFunction() {}

// Expected: Ignore
func negativeInternalTopLevelFunction() {}

// Expected:
//
//  public struct PublicNegativeLeakageContainer {
//      public init()
//      public func functionContainingNegativeLocals()
//  }
//
public struct PublicNegativeLeakageContainer {
    public init() {}
    private var privateMember = 1
    var internalMember = 2
    private struct PrivateNested { let value: Int }
    struct InternalNested { let value: Int }

    public func functionContainingNegativeLocals() {
        func localFunction() {}
        struct LocalType { let value: Int }
        let inferredLocal = LocalType(value: 1)
        localFunction()
        _ = inferredLocal
    }
}

// Expected: Ignore
private extension PublicNegativeLeakageContainer {
    func negativePrivateExtensionMethod() {}
}

// Expected: Ignore
extension NegativeInternalTopLevelType {
    func negativeInternalExtensionMethod() {}
}
