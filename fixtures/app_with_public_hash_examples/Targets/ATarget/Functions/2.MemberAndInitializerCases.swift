import Foundation

// Expected:
//
//  open class PublicMethodBaseCase {
//      public init()
//      open func openMethod()
//      public class func classMethod()
//  }
//
open class PublicMethodBaseCase {
    public init() {}
    open func openMethod() {}
    public class func classMethod() {}
}

// Expected:
//  public final class PublicMethodDerivedCase: PublicMethodBaseCase {
//      public override init()
//      public override func openMethod()
//      public static func staticMethod()
//      public func publicMethod()
//      public func asyncMethod() async
//      public func throwingMethod() throws
//      public func genericMethod<T>(_ value: T) -> T
//      public func constrainedMethod<T>(_ value: T) where T : Codable
//  }
//
public final class PublicMethodDerivedCase: PublicMethodBaseCase {
    public override init() { super.init() }
    public override func openMethod() {}
    public static func staticMethod() {}
    public func publicMethod() {}
    func internalMethod() {}
    private func privateMethod() {}
    public func asyncMethod() async {}
    public func throwingMethod() throws {}
    public func genericMethod<T>(_ value: T) -> T { value }
    public func constrainedMethod<T>(_ value: T) where T: Codable {}
}

// Expected:
//
//  public struct PublicMutatingMethodCase {
//      public var value: Int { get }
//      public init()
//      public mutating func increment()
//      public var nonmutatingValue: Int {
//          get
//          set
//      }
//  }
//
public struct PublicMutatingMethodCase {
    public private(set) var value = 0
    public init() {}
    public mutating func increment() { value += 1 }
    public var nonmutatingValue: Int {
        get { value }
        set { value = newValue }
    }
}

// Expected:
//
//  public struct PublicInitializerCase {
//      public let value: Int
//      public init(value: Int = 7)
//      public init?(failableValue: Swift.Int)
//      public init<T>(genericValue: T)
//  }
//
public struct PublicInitializerCase {
    public let value: Int
    public init(value: Int = 7) { self.value = value }
    init(internalValue: String) { value = internalValue.count }
    private init(privateValue: Double) { value = Int(privateValue) }
    public init?(failableValue: Int) {
        guard failableValue >= 0 else { return nil }
        value = failableValue
    }
    public init!(iuoValue: String) {
        guard let parsed = Int(iuoValue) else { return nil }
        value = parsed
    }
    public init<T>(genericValue: T) { value = String(describing: genericValue).count }
}

// Expected:
//
//  open class PublicRequiredInitializerCase {
//      public required init(value: Int = 0)
//      public convenience init(text: String)
//  }
//
open class PublicRequiredInitializerCase {
    public required init(value: Int = 0) {}
    public convenience init(text: String) { self.init(value: text.count) }
}
