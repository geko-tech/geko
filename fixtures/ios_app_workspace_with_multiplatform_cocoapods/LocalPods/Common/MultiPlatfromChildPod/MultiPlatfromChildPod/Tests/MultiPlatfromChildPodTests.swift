import XCTest
@testable import MultiPlatfromChildPod

class MultiPlatfromChildPodTests: XCTestCase {
    func testHello() {
        let sut = MultiPlatfromChildPodFile()

        XCTAssertEqual("MultiPlatfromChildPodFile.hello()", sut.hello())
    }
}
