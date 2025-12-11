import FeatureOneFramework
import MyAppKit
import Styles
import FeatureOneFramework
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)

        let view = UIView(frame: CGRect(x: 10, y: 10, width: 300, height: 300))
        view.backgroundColor = Styles.Color.yellow
        
        let checkImage = UIImage(named: "Check", in: StylesResources.bundle, with: nil)
        let imageView = UIImageView(image: checkImage)
        imageView.contentMode = .center
        imageView.frame = CGRect(x: 10, y: 10, width: 50, height: 50)
        view.addSubview(imageView)

        let label = UILabel()
        label.text = NSLocalizedString("greetings_text", bundle: StylesResources.bundle, comment: "")
        label.numberOfLines = 0
        label.frame = CGRect(x: 10, y: 80, width: 200, height: 100)
        view.addSubview(label)

        let viewController = UIViewController(nibName: "ViewController", bundle: StylesResources.bundle)
        viewController.view.backgroundColor = Styles.Color.blue
        viewController.view.addSubview(view)

        window?.rootViewController = viewController
        window?.makeKeyAndVisible()

        let singleFile = StylesResources.bundle.url(forResource: "jsonFile", withExtension: "json")
        guard singleFile != nil else {
            fatalError("singleFile is missing")
        }
        
        Styles.helloFromStyles()
        FeatureOneClass.start()
        
        AppKit.start()

        return true
    }
}
