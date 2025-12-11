import UIKit
import FeaturePodA
import SwiftyJSON
import MultiPlatfromParentPod
import SinglePod
import HeadersTest
import HeadersTestMappingDir
import HeadersPod
import HeadersObjcPod
import HeadersPodMappingDir
import CocoapodsPod
import FlagsTarget

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func applicationDidFinishLaunching(_: UIApplication) {
        let featurePod = FeaturePodA()
        print("AppDelegate -> \(featurePod.hello())")
        
        print(MultiPlatfromParentPodFileiOS().hello())
        print(SinglePodFileiOS().hello())
        HeaderTestsSwiftFile().test()
        test_lib()
        HeaderTestsMappingDirSwiftFile().test()
        HeadersPodSwiftFile().test()
        MyLoggerIOS().logMessage()
        MyLoggerCommon().logMessage()
        HeadersPodMappingDirSwiftFile().test()
        CocoapodsPod().sharedTestPrint()
        FlagsTargetSwiftFile().test()
        InnerFileFlagsTargetSwiftFile().test()
        TestLibraryLogger().logMessage()
    }

    func hello() -> String {
        "AppDelegate.hello()"
    }
}
