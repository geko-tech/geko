import XCTest
@testable import InterimSinglePod

class InterimSinglePodFileTests: XCTestCase {
    func testHello() {
        let sut = InterimSinglePodFile()

        XCTAssertEqual("InterimSinglePodFile.hello()", sut.hello())
    }
}
