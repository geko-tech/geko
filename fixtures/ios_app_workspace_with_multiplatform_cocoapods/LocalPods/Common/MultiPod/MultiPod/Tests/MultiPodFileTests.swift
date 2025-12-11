import XCTest
@testable import MultiPod

class MultiPodFileTests: XCTestCase {
    func testHello() {
        let sut = MultiPodFile()

        XCTAssertEqual("MultiPodFile.hello()", sut.hello())
    }
}
