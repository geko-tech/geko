import GekoKit

final class MockTestsProgressLogger: TestsProgressLogging {
    var loggedMessages: [String] = []
    func log(_ message: String) {
        loggedMessages.append(message)
    }
}
