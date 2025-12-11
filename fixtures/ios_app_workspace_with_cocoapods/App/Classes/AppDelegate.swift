import UIKit
import FeaturePodA
import SwiftyJSON

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func applicationDidFinishLaunching(_: UIApplication) {
        let featurePod = FeaturePodA()
        print("AppDelegate -> \(featurePod.hello())")
    }

    func hello() -> String {
        "AppDelegate.hello()"
    }
}
