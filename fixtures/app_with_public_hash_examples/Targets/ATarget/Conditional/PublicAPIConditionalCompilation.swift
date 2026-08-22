import Foundation

// Expected:
//
// public func publicConditionalBranchFunction() -> String
// public func publicConditionalBranchFunction() -> String
#if DEBUG
public func publicConditionalBranchFunction() -> String { "debug" }
#else
public func publicConditionalBranchFunction() -> String { "release" }
#endif

// Expected:
//
//  public struct PublicConditionalContainerCase {
//      public init()
//      public func publicConditionalMember() -> Int
//      public func publicConditionalMember() -> Int
//  }
//
public struct PublicConditionalContainerCase {
    public init() {}
    #if DEBUG
    public func publicConditionalMember() -> Int { 1 }
    #else
    public func publicConditionalMember() -> Int { 2 }
    #endif
}

// Expected:
//
// public func publicOnlyInSelectedBranchFunction()

#if DEBUG
public func publicOnlyInSelectedBranchFunction() {}
#else
func publicOnlyInSelectedBranchFunction() {}
#endif

// Expected:
//
// @available(iOS 15.0, *)
// public func publicConditionalAttributeFunction()
//
#if compiler(>=6.0)
@available(iOS 15.0, *)
#endif
public func publicConditionalAttributeFunction() {}
