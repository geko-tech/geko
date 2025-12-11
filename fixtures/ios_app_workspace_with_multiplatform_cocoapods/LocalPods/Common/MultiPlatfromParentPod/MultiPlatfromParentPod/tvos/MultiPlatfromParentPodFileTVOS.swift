import Foundation
import TVOSPod

public class MultiPlatfromParentPodFileTVOS {
    public init() {}

    public func hello() -> String {
        print(TVOSPodFile().hello())
        return "MultiPlatfromParentPodFileTVOS.hello()"
    }
}
