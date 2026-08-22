import Foundation

// Expected:
//
//  @available(iOS 15.0, *)
//  public func publicAvailableFunction()
//
@available(iOS 15.0, *)
public func publicAvailableFunction() {}

// Expected:
//
//  @MainActor
//  @available(iOS 15.0, *)
//  public final class PublicStackedAttributesCase {
//        public init()
//  }
//
@MainActor
@available(iOS 15.0, *)
public final class PublicStackedAttributesCase {
    public init() {}
}

// Expected:
//
//  @objc(PublicObjectiveCFixtureCase)
//  final public class PublicObjectiveCClassCase: NSObject {
//      @objc(publicRenamedMethod:) public dynamic func publicObjectiveCMethod(value: Int)
//  }
//
@objc(PublicObjectiveCFixtureCase)
public final class PublicObjectiveCClassCase: NSObject {
    @objc(publicRenamedMethod:)
    public dynamic func publicObjectiveCMethod(value: Int) {}
}

// Expected:
//
//  @frozen public struct PublicFrozenStructCase {
//      public let value: Int
//      public init(value: Int)
//  }
//
@frozen
public struct PublicFrozenStructCase {
    public let value: Int
    public init(value: Int) { self.value = value }
}

// Expected:
//
//  @resultBuilder
//  public enum PublicStringResultBuilder {
//      public static func buildBlock(_ components: String...) -> String
//  }
//
@resultBuilder
public enum PublicStringResultBuilder {
    public static func buildBlock(_ components: String...) -> String {
        components.joined()
    }
}

// Expected:
//
// By swiftinterface:
// public func publicResultBuilderFunction() -> Swift.String
//
// In our case i think
// @PublicStringResultBuilder
// public func publicResultBuilderFunction() -> String

@PublicStringResultBuilder
public func publicResultBuilderFunction() -> String {
    "first"
    "second"
}

// Expected:
//
//  @discardableResult
//  public func publicDiscardableResultFunction() -> Int
//
@discardableResult
public func publicDiscardableResultFunction() -> Int { 42 }

// Expected:
//
//  public enum PublicWarnUnqualifiedAccessCase {
//      @warn_unqualified_access
//      public static func publicWarnUnqualifiedAccessMethod()
//  }
//
public enum PublicWarnUnqualifiedAccessCase {
    @warn_unqualified_access
    public static func publicWarnUnqualifiedAccessMethod() {}
}
