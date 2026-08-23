// Expected: unsafe
public struct InferredNestedOuterCase {
    public struct InferredNestedInnerCase {
        public let inferredNestedValue = 42
        public init() {}
    }
}
