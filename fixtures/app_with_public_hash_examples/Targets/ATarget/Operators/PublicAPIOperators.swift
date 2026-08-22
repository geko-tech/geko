import Foundation

// Expected:
//
//  precedencegroup ParsingFixturePrecedence {
//      associativity: left
//      higherThan: AdditionPrecedence
//  }
//
precedencegroup ParsingFixturePrecedence {
    associativity: left
    higherThan: AdditionPrecedence
}

// Expected: infix operator <~> : ParsingFixturePrecedence
infix operator <~>: ParsingFixturePrecedence

// Expected:
//
//  public struct PublicOperatorValueCase: Equatable {
//      public let value: Int
//      public init(value: Int)
//  }
//
public struct PublicOperatorValueCase: Equatable {
    public let value: Int
    public init(value: Int) { self.value = value }
}

// Expected:
//
// public func <~> (lhs: PublicOperatorValueCase, rhs: PublicOperatorValueCase) -> PublicOperatorValueCase
//
public func <~> (lhs: PublicOperatorValueCase, rhs: PublicOperatorValueCase) -> PublicOperatorValueCase {
    PublicOperatorValueCase(value: lhs.value + rhs.value)
}
