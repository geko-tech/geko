import Foundation

// Expected:
//
//  public protocol PublicExistentialProtocol {
//      func existentialValue() -> Int
//  }
//
public protocol PublicExistentialProtocol {
    func existentialValue() -> Int
}

// Expected:
//
//  public struct PublicExistentialConformer: PublicExistentialProtocol {
//      public init()
//      public func existentialValue() -> Int
//  }
//
public struct PublicExistentialConformer: PublicExistentialProtocol {
    public init() {}
    public func existentialValue() -> Int { 1 }
}

// Expected:
//
//  public struct PublicGenericTypeCase<Element> {
//      public let element: Element
//      public init(element: Element)
//  }
//
public struct PublicGenericTypeCase<Element> {
    public let element: Element
    public init(element: Element) { self.element = element }
}

// Expected:
//
//  public struct PublicMultiGenericTypeCase<Key, Value> where Key: Hashable {
//      public let dictionary: [Key: Value]
//      public init(dictionary: [Key: Value])
//  }
//
public struct PublicMultiGenericTypeCase<Key, Value> where Key: Hashable {
    public let dictionary: [Key: Value]
    public init(dictionary: [Key: Value]) { self.dictionary = dictionary }
}

// Expected:
//
//  extension PublicExistentialProtocol {
//      public func returningSelf() -> Self
//  }
//
public extension PublicExistentialProtocol {
    func returningSelf() -> Self { self }
}
