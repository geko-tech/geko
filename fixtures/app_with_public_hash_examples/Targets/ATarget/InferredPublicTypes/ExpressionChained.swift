// Expected: unsafe
public let inferredGlobalChainedExpressionCase = [1, 2, 3]
    .map(String.init)
    .joined(separator: ",")
