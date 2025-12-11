import Foundation
import Styles
import SinglePod
import HeadersObjcPod
import HeadersPod
import SwiftyJSON

public final class FeatureOneClass {
    public static func start() {
        print("Hello from FeatureOne")
        print("Sky is \(Styles.Color.blue)")
        print("Hello from cocoapods: \(SinglePodFile().hello())")
        print("Hello from HeadersObjcPod: \(HeadersObjcPodCommon().hello())")
        HeadersPodSwiftFile().test()
        test_lib()
    }
}
