// Expected: unsafe
public struct InferredLazyStructPropertyCase {
    public lazy var inferredLazyStructValue = InferredConstructorHelperCase()
    public init() {}
}
