import XCTest
@testable import MultiPlatfromParentPod

class MultiPlatfromParentPodTests: XCTestCase {
    func testHello() {
        let sut = MultiPlatfromParentPodFile()

        XCTAssertEqual("MultiPlatfromParentPodFile.hello()", sut.hello())
    }
}
