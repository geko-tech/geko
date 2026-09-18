import Foundation
import GekoSupport

public protocol TestsProgressLogging: AnyObject {
    func log(_ message: String)
}

public final class TestsProgressLogger: TestsProgressLogging {

    public init() {}

    public func log(_ message: String) {
        guard !LogOutput.suppressesHumanOutput else { return }
        print(message)
    }
}
