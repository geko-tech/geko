import Foundation

// Expected:
//
// public func fooGlobalPublicFunc(value: Int) -> String
// public func fooGlobalLabledFunc(_ value: Int, named another: String)
// public func fooGlobalVariadic(_ values: Int...)
// public func fooGlobalInout(_ value: inout Int)
// public func fooGlobalAsyncThrows() async throws -> String
// public func fooGlobalRethrows(_ body: () throws -> Void) rethrows
// public func fooGlobalTypedThrows() throws(FooError)
// public func fooGeneric<T>(_ value: T) -> T
// public func fooGenericWhere<T>(_ value: T) where T : Decodable, T : Encodable // or codable
// public func fooMultipleGeneric<T, U>(_ t: T, _ u: U) where T : Collection, U == T.Element
// public func fooAttributes(handler: @escaping @Sendable () -> Void)
// public func fooBorrowing(_ value: borrowing FooPublicWithMembers)
// public func fooConsuming(_ value: consuming FooPublicWithMembers)

public func fooGlobalPublicFunc(value: Int) -> String {
    return "Foo"
}

func fooGlobalIntarnalFunc(value: Int) -> String {
    return "Foo"
}

public func fooGlobalLabledFunc(_ value: Int, named another: String) {}

public func fooGlobalVariadic(_ values: Int...) {}

public func fooGlobalInout(_ value: inout Int) {}

public func fooGlobalAsyncThrows() async throws -> String {
    ""
}

public func fooGlobalRethrows(_ body: () throws -> Void) rethrows {}

public enum FooError: Error {
    case failed
}

public func fooGlobalTypedThrows() throws(FooError) {}

public func fooGeneric<T>(_ value: T) -> T {
    value
}

public func fooGenericWhere<T>(_ value: T) where T: Codable {}

public func fooMultipleGeneric<T, U>(_ t: T, _ u: U) where T: Collection, T.Element == U {}

public func fooAttributes(handler: @escaping @Sendable () -> Void) {}

public func fooBorrowing(_ value: borrowing FooPublicWithMembers) {}

public func fooConsuming(_ value: consuming FooPublicWithMembers) {}

public actor SomeActor {}

public func foo(actor: isolated SomeActor) {}
