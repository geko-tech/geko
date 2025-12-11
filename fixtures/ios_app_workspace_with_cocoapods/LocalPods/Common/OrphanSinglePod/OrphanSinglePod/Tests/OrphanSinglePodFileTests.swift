import XCTest
@testable import OrphanSinglePod

class OrphanSinglePodFileTests: XCTestCase {
    func testHello() {
        let sut = OrphanSinglePodFile()

        XCTAssertEqual("OrphanSinglePodFile.hello()", sut.hello())
    }
}
