import FeaturePodA
import XCTest

class FeaturePodAFileTests: XCTestCase {
    func testHello() {
        let sut = FeaturePodA()

        XCTAssertEqual("FeaturePodAFile.hello()", sut.hello())
    }
}
