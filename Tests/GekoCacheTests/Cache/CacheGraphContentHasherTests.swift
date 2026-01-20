import Foundation
import GekoCache
import GekoGraph
import ProjectDescription
import XCTest

@testable import GekoCacheTesting
@testable import GekoCoreTesting
@testable import GekoSupportTesting

final class CacheGraphContentHasherTests: GekoUnitTestCase {
    var graphContentHasher: MockGraphContentHasher!
    var contentHasher: MockContentHasher!
    var subject: CacheGraphContentHasher!

    override func setUp() {
        super.setUp()

        graphContentHasher = MockGraphContentHasher()
        contentHasher = MockContentHasher()
        system.swiftlangVersionStub = {
            "5.4.2"
        }
        subject = CacheGraphContentHasher(
            graphContentHasher: graphContentHasher,
            additionalCacheStringsHasher: AdditionalCacheStringsHasher(contentHasher: contentHasher),
            contentHasher: contentHasher
        )
    }

    override func tearDown() {
        graphContentHasher = nil
        contentHasher = nil
        subject = nil
        super.tearDown()
    }

    func test_contentHashes_when_no_excluded_targets_all_hashes_are_computed() throws {
        var contentHashesCalled = false
        let includedTarget = GraphTarget(
            path: "/Project/Path",
            target: Target.test(name: "Included", product: .framework),
            project: Project.test()
        )
        graphContentHasher.contentHashesStub = { _, _, filter, _, _ in
            contentHashesCalled = true
            XCTAssertTrue(filter(includedTarget))
            return [:]
        }
        _ = try subject.contentHashes(
            for: Graph.test(workspace: .test()),
            sideTable: GraphSideTable(),
            cacheProfile: ProjectDescription.Cache.Profile(name: "Development", configuration: "Debug", platforms: [.iOS: .options(arch: .arm64)]),
            cacheUserVersion: nil,
            cacheOutputType: .framework,
            cacheDestination: .simulator,
            unsafe: false
        )
        XCTAssertTrue(contentHashesCalled)
    }

    func test_contentHashes_when_excluded_targets_excluded_hashes_are_not_computed() throws {
        var contentHashesCalled = false
        let excludedTarget = GraphTarget(
            path: "/Project/Path",
            target: Target.test(name: "Excluded", product: .framework),
            project: Project.test()
        )
        let includedTarget = GraphTarget(
            path: "/Project/Path",
            target: Target.test(name: "Included", product: .framework),
            project: Project.test()
        )
        graphContentHasher.contentHashesStub = { _, _, filter, _, _ in
            contentHashesCalled = true
            XCTAssertTrue(filter(includedTarget))
            XCTAssertFalse(filter(excludedTarget))
            return [:]
        }
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["Excluded"]
        _ = try subject.contentHashes(
            for: Graph.test(workspace: .test()),
            sideTable: sideTable,
            cacheProfile: ProjectDescription.Cache.Profile(name: "Development", configuration: "Debug", platforms: [.iOS: .options(arch: .arm64)]),
            cacheUserVersion: nil,
            cacheOutputType: .framework,
            cacheDestination: .simulator,
            unsafe: false
        )
        XCTAssertTrue(contentHashesCalled)
    }

    func test_contentHashes_when_excluded_targets_resources_hashes_are_not_computed() throws {
        let project = Project.test()

        var contentHashesCalled = false
        let excludedTarget = GraphTarget(
            path: "/Project/Path",
            target: Target.test(name: "Excluded", product: .framework),
            project: project
        )
        let excludedTargetResource = GraphTarget(
            path: "/Project/Path",
            target: Target.test(name: "\(project.name)_Excluded", product: .bundle),
            project: project
        )
        let includedTarget = GraphTarget(
            path: "/Project/Path",
            target: Target.test(name: "Included", product: .framework),
            project: Project.test()
        )
        graphContentHasher.contentHashesStub = { _, _, filter, _, _ in
            contentHashesCalled = true
            XCTAssertTrue(filter(includedTarget))
            XCTAssertFalse(filter(excludedTarget))
            XCTAssertFalse(filter(excludedTargetResource))
            return [:]
        }
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["Excluded", "\(project.name)_Excluded"]
        _ = try subject.contentHashes(
            for: Graph.test(workspace: .test()),
            sideTable: sideTable,
            cacheProfile: ProjectDescription.Cache.Profile(name: "Development", configuration: "Debug", platforms: [.iOS: .options(arch: .arm64)]),
            cacheUserVersion: nil,
            cacheOutputType: .framework,
            cacheDestination: .simulator,
            unsafe: false
        )
        XCTAssertTrue(contentHashesCalled)
    }
    
    func test_contentHashes_when_unsafe_excluded_targets_excluded_hashes_are_computed() throws {
        var contentHashesCalled = false
        let excludedTarget = GraphTarget(
            path: "/Project/Path",
            target: Target.test(name: "Excluded", product: .framework),
            project: Project.test()
        )
        let includedTarget = GraphTarget(
            path: "/Project/Path",
            target: Target.test(name: "Included", product: .framework),
            project: Project.test()
        )
        graphContentHasher.contentHashesStub = { _, _, filter, _, _ in
            contentHashesCalled = true
            XCTAssertTrue(filter(includedTarget))
            XCTAssertTrue(filter(excludedTarget))
            return [:]
        }
        var sideTable = GraphSideTable()
        sideTable.workspace.focusedTargets = ["Excluded"]
        _ = try subject.contentHashes(
            for: Graph.test(workspace: .test()),
            sideTable: sideTable,
            cacheProfile: ProjectDescription.Cache.Profile(name: "Development", configuration: "Debug", platforms: [.iOS: .options(arch: .arm64)]),
            cacheUserVersion: nil,
            cacheOutputType: .framework,
            cacheDestination: .simulator,
            unsafe: true
        )
        XCTAssertTrue(contentHashesCalled)
    }
}
