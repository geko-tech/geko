import Foundation
import iOS
import Documentation

public class SinglePodFileiOS {
    public init() {}

    public func hello() -> String {
        iOS().iosTestPrint()
        Documentation().sharedTestPrint()
        return "SinglePodFileiOS.hello()"
    }
}
