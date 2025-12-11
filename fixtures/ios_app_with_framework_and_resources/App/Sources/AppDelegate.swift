import Framework1
import StaticFramework
import StaticFramework2
import StaticFramework3
import StaticFramework4
import StaticFramework5
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    let staticFrameworkResources = StaticFrameworkResources()
    let staticFramework2Resources = StaticFramework2Resources()
    let resourcesStaticFramework3 = ResourcesStaticFramework3()
    let resourcesStaticFramework4 = ResourcesStaticFramework4()

    func applicationDidFinishLaunching(_: UIApplication) {
        let framework1 = Framework1File()

        print(hello())
        print("AppDelegate -> \(framework1.hello())")
        print("Main bundle image: \(String(describing: UIImage(named: "geko")))")
        print("Asset catalogue image: \(String(describing: UIImage(named: "assetCatalogLogo")))")
        print("Strings: \(AppStrings.Greetings.morning)")
        print("String dicts: \(AppStrings.App.appleCount(1))")
        print("StaticFrameworkResource image: \(String(describing: staticFrameworkResources.geko))")
        print("StaticFramework2Resource image: \(String(describing: staticFramework2Resources.loadImage()))")
        print("StaticFramework3Resource image: \(String(describing: resourcesStaticFramework3.loadImage()))")
        print(
            "StaticFramework3Resource asset catalogue image: \(String(describing: resourcesStaticFramework3.assetCatalogLogo()))"
        )
        print("StaticFramework4Resource image: \(String(describing: resourcesStaticFramework4.loadImage()))")
        print(
            "StaticFramework5Resource image: \(String(describing: UIImage(named: "StaticFramework5Resources-geko", in: StaticFramework5Resources.bundle, compatibleWith: nil)))"
        )
    }

    func hello() -> String {
        "AppDelegate.hello()"
    }
}

public enum AppStrings {
  public enum App {
  
    public static let app = AppStrings.tr("App", "app")

    public static func appleCount(_ p1: Int) -> String {
      return AppStrings.tr("App", "apple_count",p1)
    }
  }
  public enum Greetings {
    public static let morning = AppStrings.tr("Greetings", "morning")
  }

  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = AppResources.bundle.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}
