import Foundation
import IOSPod

public class MultiPlatfromParentPodFileiOS {
    public init() {}

    public func hello() -> String {
        print(IOSPodFile().hello())
        return "MultiPlatfromParentPodFileiOS.hello()"
    }
}
