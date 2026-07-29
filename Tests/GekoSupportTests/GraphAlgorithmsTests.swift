import XCTest

@testable import GekoSupport

final class GraphAlgorithmsTests: XCTestCase {
    func test_topologicalSort_returnsReversePostorder() throws {
        let graph = [
            "A": ["B", "C"],
            "B": ["D"],
            "C": ["D"],
            "D": [],
        ]

        let result = try topologicalSort(["A"]) { graph[$0] ?? [] }

        XCTAssertEqual(result, ["A", "C", "B", "D"])
    }

    func test_topologicalSort_ignoresAlreadyVisitedRoots() throws {
        let graph = [
            "A": ["B"],
            "B": [],
        ]

        let result = try topologicalSort(["A", "B", "A"]) { graph[$0] ?? [] }

        XCTAssertEqual(result, ["A", "B"])
    }

    func test_topologicalSort_throwsWhenCycleIsDetected() {
        let graph = [
            "A": ["B"],
            "B": ["C"],
            "C": ["A"],
        ]

        XCTAssertThrowsError(try topologicalSort(["A"]) { graph[$0] ?? [] }) { error in
            guard
                let graphError = error as? GraphError,
                case .unexpectedCycle = graphError
            else {
                return XCTFail("Expected GraphError.unexpectedCycle, got \(error)")
            }
        }
    }

    func test_topologicalSort_handlesLongChainsWithoutRecursion() throws {
        let nodeCount = 20_000

        let result = try topologicalSort([0]) { node in
            node + 1 < nodeCount ? [node + 1] : []
        }

        XCTAssertEqual(result.count, nodeCount)
        XCTAssertEqual(result.first, 0)
        XCTAssertEqual(result.last, nodeCount - 1)
    }

    func test_findCycle_returnsPathAndCycle() {
        let graph = [
            "A": ["B"],
            "B": ["C"],
            "C": ["B"],
        ]

        let result = findCycle(["A"]) { graph[$0] ?? [] }

        XCTAssertEqual(result?.path, ["A"])
        XCTAssertEqual(result?.cycle, ["B", "C"])
    }

    func test_findCycle_handlesLongAcyclicChainsWithoutRecursion() {
        let nodeCount = 20_000

        let result = findCycle([0]) { node in
            node + 1 < nodeCount ? [node + 1] : []
        }

        XCTAssertNil(result)
    }
}
