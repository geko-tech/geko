import Foundation
import UIKit

public class ResourcesStaticFramework4 {
    public let name = "StaticFramework4Resources"
    public init() {}

    public func loadImage() -> UIImage? {
        UIImage(
            named: "StaticFramework4Resources-geko",
            in: StaticFramework4Resources.bundle,
            compatibleWith: nil
        )
    }
}
