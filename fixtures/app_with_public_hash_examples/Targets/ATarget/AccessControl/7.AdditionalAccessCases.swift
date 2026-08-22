import Foundation

// Expected: ignore
struct InternalStructCase {
    var value: Int
}

// Expected: ignore
private struct PrivateStructCase {
    var value: Int
}

// Expected: public struct PublicEmptyStructCase {}
public struct PublicEmptyStructCase {}
// Expected: public enum PublicEmptyEnumCase {}
public enum PublicEmptyEnumCase {}
// Expected: public actor PublicActorCase {}
public actor PublicActorCase {}
// Expected: open class OpenClassCase {}
open class OpenClassCase {}

// Expected:
//
//  public struct PublicMixedAccessContainerCase {
//      public let publicProperty: Int
//      public init(publicProperty: Int = 3)
//      public func publicMethod()
//  }
//
public struct PublicMixedAccessContainerCase {
    private let privateProperty = 1
    let internalProperty = 2
    public let publicProperty: Int

    public init(publicProperty: Int = 3) {
        self.publicProperty = publicProperty
    }

    private func privateMethod() {}
    func internalMethod() {}
    public func publicMethod() {}
}

// Expected: public struct PublicPrivateNestedOuterCase {}
public struct PublicPrivateNestedOuterCase {
    private struct PrivateNestedCase {
        func publicLookingMethod() {}
    }
}
