import Foundation

// Public Accessors

@objc
public class LocalSwiftPackageStylesResources: NSObject {
    @objc public class var bundle: Bundle {
        return .module
    }
}
