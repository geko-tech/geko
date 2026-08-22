import Foundation

// Expected:
//
//  public protocol PublicComprehensiveProtocol: AnyObject, Sendable {
//      associatedtype Item
//      associatedtype EncodedItem: Codable
//      associatedtype DefaultItem = Int
//      typealias Callback = @Sendable (Item) -> Void
//      init(value: Item)
//      func requiredMethod(_ value: Item) -> Self
//      func asyncRequirement() async
//      func throwingRequirement() throws
//      var readOnlyProperty: Item { get }
//      var mutableProperty: Item { get set }
//      subscript(index: Int) -> Item { get set }
//  }
//
public protocol PublicComprehensiveProtocol: AnyObject, Sendable {
    associatedtype Item
    associatedtype EncodedItem: Codable
    associatedtype DefaultItem = Int
    typealias Callback = @Sendable (Item) -> Void

    init(value: Item)
    func requiredMethod(_ value: Item) -> Self
    func asyncRequirement() async
    func throwingRequirement() throws
    var readOnlyProperty: Item { get }
    var mutableProperty: Item { get set }
    subscript(index: Int) -> Item { get set }
}

// Expected: Ignored
protocol InternalParsingProtocol {
    associatedtype Value
    func hiddenRequirement() -> Value
}

// Expected:
//
// public protocol PublicMarkerProtocol {}
//
public protocol PublicMarkerProtocol {}

// Expected:
//
//  public protocol PublicCrossFileProtocol {
//      func crossFileRequirement() -> String
//  }
//
public protocol PublicCrossFileProtocol {
    func crossFileRequirement() -> String
}

// Expected:
//
//  public struct PublicHeaderConformanceCase: PublicMarkerProtocol, Equatable, Sendable {
//      public let value: Int
//      public init(value: Int)
//  }
//
public struct PublicHeaderConformanceCase: PublicMarkerProtocol, Equatable, Sendable {
    public let value: Int
    public init(value: Int) { self.value = value }
}

// Expected:
//
//  public struct PublicGenericConformanceCase<Value>: Equatable where Value: Equatable {
//      public let value: Value
//      public init(value: Value)
//  }
//
public struct PublicGenericConformanceCase<Value>: Equatable where Value: Equatable {
    public let value: Value
    public init(value: Value) { self.value = value }
}
