// Expected: unsafe
public let inferredSwitchExpressionCase = switch Int.random(in: 0...2) {
case 0: "zero"
case 1: "one"
default: "other"
}
