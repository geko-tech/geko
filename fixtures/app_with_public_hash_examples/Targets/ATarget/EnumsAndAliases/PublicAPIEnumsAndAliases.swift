import Foundation

// Expected:
//
// public enum PublicPlainEnumCase { case first, second }
//
public enum PublicPlainEnumCase { case first, second }

// Expected:
//
//  public enum PublicRawValueEnumCase: Int {
//      case first
//      case second
//  }
//
public enum PublicRawValueEnumCase: Int {
    case first = 10
    case second = 20
}

// Expected:
//
//  public enum PublicAssociatedValueEnumCase {
//      case number(value: Int)
//      case pair(String, count: Int)
//  }
//
public enum PublicAssociatedValueEnumCase {
    case number(value: Int)
    case pair(String, count: Int)
}

// Expected:
//
//  public indirect enum PublicIndirectEnumCase {
//      case leaf(Int)
//      case branch(PublicIndirectEnumCase, PublicIndirectEnumCase)
//  }
//
public indirect enum PublicIndirectEnumCase {
    case leaf(Int)
    case branch(PublicIndirectEnumCase, PublicIndirectEnumCase)
}

// Expected:
//
//  public enum PublicIndirectCaseEnumCase {
//      case value(Int)
//      indirect case next(PublicIndirectCaseEnumCase)
//  }
//
public enum PublicIndirectCaseEnumCase {
    case value(Int)
    indirect case next(PublicIndirectCaseEnumCase)
}

// Expected:
//
//  public enum PublicEnumMemberAccessCase {
//      case visible
//      public func publicEnumMethod()
//  }
//
public enum PublicEnumMemberAccessCase {
    case visible
    public func publicEnumMethod() {}
    func internalEnumMethod() {}
}

// Expected: public typealias PublicGlobalAliasCase = [String: Int]
public typealias PublicGlobalAliasCase = [String: Int]
// Expected: ignore
typealias InternalGlobalAliasCase = Set<Int>
// Expected:
//  public typealias PublicComplexGenericAliasCase<Key: Hashable, Value> = Dictionary<Key, Array<Value>>
public typealias PublicComplexGenericAliasCase<Key: Hashable, Value> = Dictionary<Key, Array<Value>>
// Expected: public typealias PublicClosureAliasCase = @Sendable (Int, String) async throws -> Bool
public typealias PublicClosureAliasCase = @Sendable (Int, String) async throws -> Bool

// Expected:
//
//  public struct PublicNestedAliasContainerCase {
//      public typealias NestedAlias = Result<String, FooError>
//  }
//
public struct PublicNestedAliasContainerCase {
    public typealias NestedAlias = Result<String, FooError>
}
