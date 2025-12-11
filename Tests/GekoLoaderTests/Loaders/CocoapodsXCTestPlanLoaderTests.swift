import Foundation
import XCTest
import GekoSupportTesting

@testable import GekoLoader

final class CocoapodsXCTestPlanLoaderTests: GekoUnitTestCase {

    func testLoad() throws {
        //arrange
        let targetNamesMock = ["A", "B", "C"]
        let testPlanPathsMock = try targetNamesMock.flatMap { try createFiles([$0], content: testPlanMock(targetName: $0)) }

        let sut = CocoapodsXCTestPlanLoader()

        //act
        let testPlansByTargets = try sut.loadXCTestPlans(testPlanPaths: testPlanPathsMock)

        //assert
        XCTAssertEqual(testPlansByTargets["A"], [testPlanPathsMock[0]])
        XCTAssertEqual(testPlansByTargets["B"], [testPlanPathsMock[1]])
        XCTAssertEqual(testPlansByTargets["C"], [testPlanPathsMock[2]])

    }

    func testSeveralTargets() throws {
        //arrange
        let testPlanContent = """
        {
          "configurations": [
            {
              "id": "48E7EE2C-01CC-48A4-A410-80738F91F794",
              "name": "Configuration 1",
              "options": {}
            }
          ],
          "defaultOptions": {},
          "testTargets": [
            {
              "target": {
                "containerPath": "container:Atomic.xcodeproj",
                "identifier": "AAD73CEB394662613913580F",
                "name": "A"
              }
            },
            {
              "target": {
                "containerPath": "container:Atomic.xcodeproj",
                "identifier": "AAD73CEB394662613913580F",
                "name": "B"
              }
            },
            {
              "target": {
                "containerPath": "container:Atomic.xcodeproj",
                "identifier": "AAD73CEB394662613913580F",
                "name": "C"
              }
            }
          ],
          "version": 1
        }
        """

        let testPlanPathsMock = try createFiles(["a.xctestplan"], content: testPlanContent)

        let sut = CocoapodsXCTestPlanLoader()

        //act
        let testPlansByTargets = try sut.loadXCTestPlans(testPlanPaths: testPlanPathsMock)

        //assert
        XCTAssertEqual(testPlansByTargets["A"], [testPlanPathsMock[0]])
        XCTAssertEqual(testPlansByTargets["B"], [testPlanPathsMock[0]])
        XCTAssertEqual(testPlansByTargets["C"], [testPlanPathsMock[0]])

    }
}

extension CocoapodsXCTestPlanLoaderTests {

    private func testPlanMock(targetName: String) -> String {
        return """
        {
          "configurations": [
            {
              "id": "48E7EE2C-01CC-48A4-A410-80738F91F794",
              "name": "Configuration 1",
              "options": {}
            }
          ],
          "defaultOptions": {},
          "testTargets": [
            {
              "target": {
                "containerPath": "container:Atomic.xcodeproj",
                "identifier": "AAD73CEB394662613913580F",
                "name": "\(targetName)"
              }
            }
          ],
          "version": 1
        }
        """
    }
}
