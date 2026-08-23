// Expected: safe
public struct InternalInferenceShouldRemainSafeCase {
    let internalInferredValue = 42
    public init() {}
    public func publicMethod() {}
}
