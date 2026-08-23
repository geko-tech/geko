// Expected: safe
public func localInferenceShouldRemainSafeCase() -> Int {
    let inferredLocalValue = 42
    return inferredLocalValue
}
