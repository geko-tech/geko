import Foundation

// Expected: public func fooGlobalPublicFunc(value: Int) -> String
public func fooGlobalPublicFunc(value: Int) -> String {
    return "Foo"
}

// Expected: ignore
func fooGlobalIntarnalFunc(value: Int) -> String {
    return "Foo"
}

// Expected: public func fooPublicGlobalReturningFunction() -> String
public func fooPublicGlobalReturningFunction() -> String { "value" }

// Expected: public func fooGlobalLabledFunc(_ value: Int, named another: String)
public func fooGlobalLabledFunc(_ value: Int, named another: String) {}

// Expected: public func fooGlobalVariadic(_ values: Int...)
public func fooGlobalVariadic(_ values: Int...) {}

// Expected: public func fooGlobalInout(_ value: inout Int)
public func fooGlobalInout(_ value: inout Int) {}

// Epxected: public func fooGlobalAsyncThrows() async throws -> String
public func fooGlobalAsyncThrows() async throws -> String {
    ""
}

// Expected: public func publicGlobalAsyncFunction() async
public func publicGlobalAsyncFunction() async {}

// Expected: public func publicGlobalThrowsFunction() throws
public func publicGlobalThrowsFunction() throws {}

// Expected: public func fooGlobalRethrows(_ body: () throws -> Void) rethrows
public func fooGlobalRethrows(_ body: () throws -> Void) rethrows {}

public enum FooError: Error {
    case failed
}

// Expected: public func fooGlobalTypedThrows() throws(FooError)
public func fooGlobalTypedThrows() throws(FooError) {}

// Expected: public func fooGeneric<T>(_ value: T) -> T
public func fooGeneric<T>(_ value: T) -> T {
    value
}

// Expected: public func fooGenericWhere<T>(_ value: T) where T: Codable
public func fooGenericWhere<T>(_ value: T) where T: Codable {}

// Expected: public func fooMultipleGeneric<T, U>(_ t: T, _ u: U) where T : Collection, U == T.Element
public func fooMultipleGeneric<T, U>(_ t: T, _ u: U) where T: Collection, T.Element == U {}

// Expected: public func fooAttribute(handler: @escaping () -> Void)
public func fooAttribute(handler: @escaping () -> Void) {}

// Expected: public func fooAttributes(handler: @escaping @Sendable () -> Void)
public func fooAttributes(handler: @escaping @Sendable () -> Void) {}


// Expected: public func fooBorrowing(_ value: borrowing FooPublicWithMembers)
public func fooBorrowing(_ value: borrowing FooPublicWithMembers) {}

// Expected: public func fooConsuming(_ value: consuming FooPublicWithMembers)
public func fooConsuming(_ value: consuming FooPublicWithMembers) {}

public actor SomeActor {}

// Expected: public func foo(actor: isolated SomeActor)
public func foo(actor: isolated SomeActor) {}

// Expected: public func fooPublicGlobalDefaultFunction(value: Int = 42)
public func fooPublicGlobalDefaultFunction(value: Int = 42) {}

// Expected:
//
// public func fooPublicGlobalComplexDefaultFunction(values: [Int] = Array(1...3).map { $0 * 2 })
//
public func fooPublicGlobalComplexDefaultFunction(
    values: [Int] = Array(1...3).map { $0 * 2 }
) {}

// Expected:
//
// public func publicProtocolCompositionFunction(_ value: any PublicExistentialProtocol & Sendable) -> Int
//
public func publicProtocolCompositionFunction(
    _ value: any PublicExistentialProtocol & Sendable
) -> Int { value.existentialValue() }

// Expected:
//
// public func publicExistentialFunction(_ value: any PublicExistentialProtocol) -> Int
//
public func publicExistentialFunction(_ value: any PublicExistentialProtocol) -> Int {
    value.existentialValue()
}

// Expected:
//
// public func publicMetatypeFunction(_ type: PublicExistentialConformer.Type) -> String
//
public func publicMetatypeFunction(_ type: PublicExistentialConformer.Type) -> String {
    String(describing: type)
}

// Expected: public func publicTupleFunction() -> (count: Int, name: String)
public func publicTupleFunction() -> (count: Int, name: String) { (1, "one") }

// Expected: public func publicFunctionTypeFunction(_ transform: (Int) -> String) -> String
public func publicFunctionTypeFunction(_ transform: (Int) -> String) -> String { transform(1) }

// Expected: public func publicOptionalFunction(_ value: Int?) -> Int?
public func publicOptionalFunction(_ value: Int?) -> Int? { value }

// Expected: public func publicNestedGenericFunction() -> [String : Result<Int, FooError>]
public func publicNestedGenericFunction() -> [String: Result<Int, FooError>] { [:] }

// Expected: public func publicOpaqueSequenceFunction() -> some Sequence<Int>
public func publicOpaqueSequenceFunction() -> some Sequence<Int> { [1, 2, 3] }


// Expected:
//
//  @inlinable
//  public func publicInlinableOpaqueSequenceFunction() -> some Sequence<Int> {
//        [4, 5, 6]
//  }
//
@inlinable
public func publicInlinableOpaqueSequenceFunction() -> some Sequence<Int> {
    [4, 5, 6]
}
