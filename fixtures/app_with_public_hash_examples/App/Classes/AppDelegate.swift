import UIKit
import ATarget
import BTarget

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func applicationDidFinishLaunching(_: UIApplication) {
        DummyA().hello()
        DummyB().hello()
    }

    func hello() -> String {
        "AppDelegate.hello()"
    }
}
