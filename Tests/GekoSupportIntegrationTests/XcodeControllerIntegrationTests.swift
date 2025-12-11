import XCTest
@testable import GekoSupport
@testable import GekoSupportTesting

class XcodeControllerIntegrationTests: GekoTestCase {
    var subject: XcodeController!

    override func setUp() {
        super.setUp()
        subject = XcodeController()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_selected_version_succeeds() throws {
        XCTAssertNoThrow(try subject.selectedVersion())
    }
}
