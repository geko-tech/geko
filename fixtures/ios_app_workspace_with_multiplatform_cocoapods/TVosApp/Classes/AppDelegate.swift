import UIKit
import SinglePod
import HeadersTest
import MultiPlatfromParentPod
import HeadersTestMappingDir
import HeadersPod
import HeadersObjcPod
import HeadersPodMappingDir
import CocoapodsPod

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = UIViewController()
        viewController.view.backgroundColor = .white
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
        
        print(SinglePodFile().hello())
        print(SinglePodFileTVOS().hello())
        
        HeaderTestsSwiftFile().test()
        test_lib()
        
        HeaderTestsMappingDirSwiftFile().test()
        
        print(MultiPlatfromParentPodFileTVOS().hello())
        
        HeadersPodSwiftFile().test()
        
        MyLoggerTVOS().logMessage()
        MyLoggerCommon().logMessage()
        
        HeadersPodMappingDirSwiftFile().test()
        CocoapodsPod().sharedTestPrint()
        
        return true
    }
}
