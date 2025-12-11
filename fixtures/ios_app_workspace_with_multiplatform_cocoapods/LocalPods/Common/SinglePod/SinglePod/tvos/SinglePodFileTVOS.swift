import Foundation
import TVUIKit
import tvOS
import Documentation

public class SinglePodFileTVOS {
    public init() {}

    public func hello() -> String {
        tvOS().tvosTestPrint()
        Documentation().sharedTestPrint()
        let some = TVMonogramContentView(configuration: .cell())
        return "SinglePodFileTVOS.hello() \(some)"
    }
}
