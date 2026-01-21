import Foundation
import GekoCore
import GekoCoreTesting
import GekoGraph
import ProjectDescription
import XCTest
import GekoSupport

@testable import GekoSupportTesting

final class AnyGraphMapperTests: GekoUnitTestCase {
    func test_map() throws {
        // Given
        let input = Graph.test(name: "input")
        let output = Graph.test(name: "output")
        let subject = AnyGraphMapper(mapper: { graph, sideTable in
            XCTAssertEqual(graph.name, input.name)
            graph.name = "output"
            return []
        })

        // When
        var got = input 
        var sideTable = GraphSideTable()
        _ = try subject.map(graph: &got, sideTable: &sideTable)

        // Then
        XCTAssertEqual(got.name, output.name)
    }
}

final class SequentialGraphMapperTests: GekoUnitTestCase {
    func test_map() async throws {
        // Given
        let firstSideEffect = SideEffectDescriptor.file(.init(path: "/first"))
        let input = Graph.test(name: "0")
        let first = AnyGraphMapper(mapper: { graph, _ in
            XCTAssertEqual(graph.name, "0")
            graph.name = "1"
            return [firstSideEffect]
        })
        let secondSideEffect = SideEffectDescriptor.file(.init(path: "/second"))
        let second = AnyGraphMapper(mapper: { graph, _ in
            XCTAssertEqual(graph.name, "1")
            graph.name = "2"
            return [secondSideEffect]
        })
        let subject = SequentialGraphMapper([first, second])

        // When
        var got = input
        var sideTable = GraphSideTable()
        let sideEffects = try await subject.map(graph: &got, sideTable: &sideTable)

        // Then
        XCTAssertEqual(got.name, "2")
        XCTAssertEqual(sideEffects, [firstSideEffect, secondSideEffect])
    }
}
