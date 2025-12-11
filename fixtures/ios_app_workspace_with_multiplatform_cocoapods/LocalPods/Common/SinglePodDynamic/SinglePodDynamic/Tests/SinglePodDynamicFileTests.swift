import XCTest
@testable import SinglePodDynamic

class SinglePodDynamicTests: XCTestCase {
    func testHello() {
        let sut = SinglePodDynamicFile()

        XCTAssertEqual("SinglePodDynamicFile.hello()", sut.hello())
    }
}
