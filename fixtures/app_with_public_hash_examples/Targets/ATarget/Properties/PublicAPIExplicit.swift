import Foundation

// Expected:
//
//  public struct PublicInferenceConstructedCase {
//      public let value: Int
//      public init(value: Int)
//  }
//
public struct PublicInferenceConstructedCase {
    public let value: Int
    public init(value: Int) { self.value = value }
}

// Expected: public func publicInferenceFactoryFunction() -> PublicInferenceConstructedCase
public func publicInferenceFactoryFunction() -> PublicInferenceConstructedCase {
    PublicInferenceConstructedCase(value: 5)
}


// Expected: public let publicExplicitIntegerCase: Int
public let publicExplicitIntegerCase: Int = 1
// Expected: public let publicExplicitStringCase: String
public let publicExplicitStringCase: String = "string"
// Expected: public let publicExplicitArrayCase: [Int]
public let publicExplicitArrayCase: [Int] = [1, 2, 3]
// Expected: public let publicExplicitDictionaryCase: [String: Int]
public let publicExplicitDictionaryCase: [String: Int] = ["one": 1]
// Expected: public let publicExplicitConstructorCase: PublicInferenceConstructedCase
public let publicExplicitConstructorCase: PublicInferenceConstructedCase = .init(value: 4)
// Expected: public let publicExplicitFactoryCase: PublicInferenceConstructedCase
public let publicExplicitFactoryCase: PublicInferenceConstructedCase = publicInferenceFactoryFunction()
// Expected: public let publicExplicitClosureCase: (Int) -> String
public let publicExplicitClosureCase: (Int) -> String = { String($0) }
// Expected: public let publicExplicitTupleCase: (count: Int, name: String)
public let publicExplicitTupleCase: (count: Int, name: String) = (1, "one")
