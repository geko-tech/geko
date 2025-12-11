import XCTest
@testable import SinglePod

class SinglePodTests: XCTestCase {
    func testHello() {
        let sut = SinglePodFile()

        XCTAssertEqual("SinglePodFile.hello()", sut.hello())
    }
}
