// Expected: safe
public struct PrivateInferenceShouldRemainSafeCase {
    private let privateInferredValue = 42
    public init() {}
    public func publicMethod() {}
}
