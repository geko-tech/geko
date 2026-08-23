import Foundation

// Expected: safe

public struct InferredConstructorHelperCase {
    public init() {}
}

public struct InferredFactoryValueCase {
    public init() {}
}

public func makeInferredFactoryValueCase() -> InferredFactoryValueCase {
    InferredFactoryValueCase()
}

public enum InferredStaticMemberHelperCase {
    public static let defaultValue: Int = 17
}

public enum InferredEnumCaseHelperCase {
    case first
    case second
}

public func inferredFunctionReferenceHelperCase(_ value: Int) -> String {
    String(value)
}

public struct InferredKeyPathModelCase {
    public var value: Int
    public init(value: Int) { self.value = value }
}

public struct InferredGenericBoxCase<Value> {
    public let value: Value
    public init(value: Value) { self.value = value }
}

public func makeInferredGenericBoxCase<T>(_ value: T) -> InferredGenericBoxCase<T> {
    InferredGenericBoxCase(value: value)
}

public struct InferredOptionalValueCase {
    public init() {}
}

public func makeInferredOptionalHelperCase() -> InferredOptionalValueCase? { nil }

public enum InferredTryErrorCase: Error { case failed }

public func makeInferredThrowingHelperCase() throws -> Int { 23 }

public protocol InferredCastProtocolCase {}

public struct InferredCastValueCase: InferredCastProtocolCase {
    public init() {}
}

@propertyWrapper
public struct InferredFixtureWrapperCase<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}

public struct InferredExtensionBaseCase {
    public init() {}
}

public final class InferredReferenceHelperCase {
    public init() {}
}

public let inferredSharedReferenceHelperCase: InferredReferenceHelperCase = .init()
