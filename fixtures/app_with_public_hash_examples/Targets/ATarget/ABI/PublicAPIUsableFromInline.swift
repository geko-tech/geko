import Foundation

// Expected:
//
//  @usableFromInline
//  internal struct UsableFromInlineStructCase {
//      @usableFromInline
//      internal let value: Int
//      @usableFromInline
//      internal init(value: Int)
//  }
//
@usableFromInline
internal struct UsableFromInlineStructCase {
    @usableFromInline internal let value: Int
    @usableFromInline internal init(value: Int) { self.value = value }
}

// Expected:
//
// @usableFromInline
// internal func usableFromInlineFunctionCase(_ value: Int) -> Int
//
@usableFromInline
internal func usableFromInlineFunctionCase(_ value: Int) -> Int { value + 1 }

// Expected: ignore
internal struct OrdinaryInternalStructCase {
    internal let value: Int
}

// Expected: ignore
internal func ordinaryInternalFunctionCase(_ value: Int) -> Int { value + 2 }

// Expected:
//
// @inlinable public func publicFunctionUsingABIVisibleCases(_ value: Swift.Int) -> Swift.Int {
//     UsableFromInlineStructCase(value: usableFromInlineFunctionCase(value)).value
// }
//
@inlinable
public func publicFunctionUsingABIVisibleCases(_ value: Int) -> Int {
    UsableFromInlineStructCase(value: usableFromInlineFunctionCase(value)).value
}
