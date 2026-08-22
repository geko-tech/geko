import Foundation

// Expected:
//
//  public struct FooPublicWithMembers {
//        public let publicValue: Int
//  }

public struct FooPublicWithMembers {
    let internalValue: Int
    public let publicValue: Int
}
