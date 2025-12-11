import Foundation
import GekoSupportTesting
import XCTest

final class SplitJsonsTests: GekoUnitTestCase {
    func test_splitJsons_whenValidJsonObjects() {
        let jsonObjects = """
            {
                "key": {
                    "key2": false
                    "key3": "sldfkjsdlfkj"
                }
            }
            {
                "key": 2
            }
            """

        let (jsons, remainder) = jsonObjects.splitJsons()

        XCTAssertEqual(jsons.count, 2)
        XCTAssertEqual(remainder, "")
        XCTAssertEqual(
            jsons.first,
            """
            {
                "key": {
                    "key2": false
                    "key3": "sldfkjsdlfkj"
                }
            }
            """
        )
        XCTAssertEqual(
            jsons.last,
            """
            {
                "key": 2
            }
            """
        )
    }

    func test_splitJsons_whenValidJsonObjectsWithIntermittentGarbage() {
        let jsonObjects = """
            {
                "key": {
                    "key2": false
                    "key3": "sldfkjsdlfkj"
                }
            }somegarbagethatneedstobedeleted'*sdlfkjds"
            {
                "key": 2
            }
            """

        let (jsons, remainder) = jsonObjects.splitJsons()

        XCTAssertEqual(jsons.count, 2)
        XCTAssertEqual(remainder, "")
        XCTAssertEqual(
            jsons.first,
            """
            {
                "key": {
                    "key2": false
                    "key3": "sldfkjsdlfkj"
                }
            }
            """
        )
        XCTAssertEqual(
            jsons.last,
            """
            {
                "key": 2
            }
            """
        )
    }

    func test_splitJsons_whenValidJsonObjectsWithGarbageAtTheEnd() {
        let jsonObjects = """
            {
                "key": {
                    "key2": false
                    "key3": "sldfkjsdlfkj"
                }
            }
            {
                "key": 2
            }garbageattheend
            """

        let (jsons, remainder) = jsonObjects.splitJsons()

        XCTAssertEqual(jsons.count, 2)
        XCTAssertEqual(remainder, "garbageattheend")
        XCTAssertEqual(
            jsons.first,
            """
            {
                "key": {
                    "key2": false
                    "key3": "sldfkjsdlfkj"
                }
            }
            """
        )
        XCTAssertEqual(
            jsons.last,
            """
            {
                "key": 2
            }
            """
        )
    }

    func test_splitJsons_whenInvalidJsonObjects() {
        let jsonObjects = """
            {
                "key": {
                    "key2": false
                    "key3": "sldfkjsdlfkj"
                }
            }
            {
                "key": 2
            """

        let (jsons, remainder) = jsonObjects.splitJsons()

        XCTAssertEqual(jsons.count, 1)
        XCTAssertEqual(
            remainder,
            """

            {
                "key": 2
            """
        )
        XCTAssertEqual(
            jsons.first,
            """
            {
                "key": {
                    "key2": false
                    "key3": "sldfkjsdlfkj"
                }
            }
            """
        )
    }
}
