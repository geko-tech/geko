import XCTest

import FeaturePodB

class FeaturePodBFileTests: XCTestCase {
    func testHello() {
        let sut = FeaturePodB()

        XCTAssertEqual("FeaturePodBFile.hello()", sut.hello())
    }
}
