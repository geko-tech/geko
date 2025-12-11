import Foundation
import FeaturePodAInterfaces
import SwiftyJSON

public class FeaturePodA: FeaturePodAInterfacesFile {
    public init() {}

    public func hello() -> String {
        let json = JSON(stringLiteral: "{\"test\": 123}")
        return "FeaturePodAFile.hello()"
    }
}
