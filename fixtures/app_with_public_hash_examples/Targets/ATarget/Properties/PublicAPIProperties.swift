import Foundation

// Expected:
//
//  public final class PublicPropertyReferenceCase {
//      public init()
//  }
//
public final class PublicPropertyReferenceCase {
    public init() {}
}

// Expected:
//
//  open class PublicPropertyContainerCase {
//      public let immutable: Int
//      public var mutable: Int
//      public static let staticProperty: Int
//      open class var classProperty: Int {}
//      public lazy var lazyProperty: String
//      public weak var weakProperty: PublicPropertyReferenceCase?
//      public unowned var unownedProperty: PublicPropertyReferenceCase
//      public private(set) var privateSetterProperty: Int
//      public internal(set) var internalSetterProperty: Int
//      public var getterOnlyProperty: Int {}
//      public var getterSetterProperty: Int {
//          get
//          set
//      }
//      @inlinable public var inlinableGetterProperty: Int { 10 }
//      public init(reference: PublicPropertyReferenceCase)
//  }
//
open class PublicPropertyContainerCase {
    public let immutable: Int = 1
    public var mutable: Int = 2
    let internalProperty: Int = 3
    private var privateProperty: Int = 4
    public static let staticProperty: Int = 5
    open class var classProperty: Int { 6 }
    public lazy var lazyProperty: String = "lazy"
    public weak var weakProperty: PublicPropertyReferenceCase?
    public unowned var unownedProperty: PublicPropertyReferenceCase
    public private(set) var privateSetterProperty: Int = 7
    public internal(set) var internalSetterProperty: Int = 8
    public var getterOnlyProperty: Int { 9 }
    public var getterSetterProperty: Int {
        get { mutable }
        set { mutable = newValue }
    }
    @inlinable public var inlinableGetterProperty: Int { 10 }

    public init(reference: PublicPropertyReferenceCase) {
        unownedProperty = reference
    }
}

// Expected:
//
//  public struct PublicSubscriptContainerCase {
//      public init()
//      public subscript(index: Int) -> String
//      public subscript(mutable index: Swift.Int) -> String {
//          get
//          set
//      }
//      public subscript<T>(generic value: T) -> String
//      public subscript<C: Collection>(first values: C) -> C.Element? where C.Element: Equatable
//  }
//
public struct PublicSubscriptContainerCase {
    private var storage: [Int: String] = [:]
    public init() {}
    public subscript(index: Int) -> String { storage[index, default: ""] }
    public subscript(mutable index: Int) -> String {
        get { storage[index, default: ""] }
        set { storage[index] = newValue }
    }
    subscript(internal index: UInt) -> String { "\(index)" }
    public subscript<T>(generic value: T) -> String { String(describing: value) }
    public subscript<C: Collection>(first values: C) -> C.Element? where C.Element: Equatable {
        values.first
    }
}
