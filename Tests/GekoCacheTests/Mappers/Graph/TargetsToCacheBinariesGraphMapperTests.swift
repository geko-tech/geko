import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription
import XCTest

@testable import GekoCloudTesting
@testable import GekoCache
@testable import GekoCacheTesting
@testable import GekoCoreTesting
@testable import GekoGraphTesting
@testable import GekoSupportTesting

final class TargetsToCacheBinariesGraphMapperTests: GekoUnitTestCase {
    private var cacheContextFolderProvider: CacheContextFolderProviderMock!
    private var cacheLatestPathStore: CacheLatestPathStoreMock!
    private var cacheStorage: MockCacheStorage!
    private var cacheGraphMutator: MockCacheGraphMutator!
    private var subject: TargetsToCacheBinariesGraphMapper!
    private var config: Config!
    private var clock = WallClock()
    private var formatter = TimeTakenLoggerFormatter()

    override func setUp() {
        super.setUp()
        config = .test()
        cacheContextFolderProvider = CacheContextFolderProviderMock()
        cacheContextFolderProvider.stubContextFolderName = "Debug-arm64"
        cacheLatestPathStore = CacheLatestPathStoreMock()
        cacheStorage = MockCacheStorage()
        cacheGraphMutator = MockCacheGraphMutator()
        subject = TargetsToCacheBinariesGraphMapper(
            unsafe: false,
            hashesByCacheableTarget: [:],
            cache: cacheStorage,
            cacheGraphMutator: cacheGraphMutator,
            clock: clock,
            timeTakenLoggerFormatter: formatter,
            logging: false
        )
    }

    override func tearDown() {
        cacheContextFolderProvider = nil
        cacheLatestPathStore = nil
        config = nil
        cacheGraphMutator = nil
        subject = nil
        super.tearDown()
    }

    func test_map_when_all_binaries_are_fetched_successfully() async throws {
        let path = try temporaryPath()
        let project = Project.test(path: path)

        // Given
        //
        //    App+----> B (Framework)+----> C (Framework)
        //
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cGraphTarget = GraphTarget.test(path: path, target: cFramework)
        let cXCFrameworkPath = path.appending(component: "C.xcframework")
        let cHash = "C"

        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bGraphTarget = GraphTarget.test(path: path, target: bFramework)
        let bHash = "B"
        let bXCFrameworkPath = path.appending(component: "B.xcframework")

        let app = Target.test(name: "App", platform: .iOS, product: .app)
        let appGraphTarget = GraphTarget.test(path: path, target: app)
        let appHash = "App"

        let inputGraph = Graph.test(
            name: "input",
            workspace: .test(),
            projects: [path: project],
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
                .target(name: app.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                ],
            ]
        )
        let outputGraph = Graph.test(
            name: "output",
            projects: inputGraph.projects,
            dependencies: inputGraph.dependencies
        )

        let contentHashes = [
            cGraphTarget.target.name: cHash,
            bGraphTarget.target.name: bHash,
            appGraphTarget.target.name: appHash,
        ]

        let cache = MockCacheStorage()
        cache.existsStub = { name, hash in
            switch hash {
            case bHash:
                XCTAssertEqual(name, "B")
                return true
            case cHash:
                XCTAssertEqual(name, "C")
                return true
            default:
                return false
            }
        }
        

        cache.fetchStub = { name, hash in
            switch hash {
            case bHash:
                XCTAssertEqual(name, "B")
                return bXCFrameworkPath
            case cHash:
                XCTAssertEqual(name, "C")
                return cXCFrameworkPath
            default:
                XCTFail("Unexpected call to fetch")
                return "/"
            }
        }
        cacheGraphMutator.stubbedMapResult = outputGraph
        
        subject = TargetsToCacheBinariesGraphMapper(
            unsafe: false,
            hashesByCacheableTarget: contentHashes,
            cache: cache,
            cacheGraphMutator: cacheGraphMutator,
            clock: clock,
            timeTakenLoggerFormatter: formatter,
            logging: false
        )

        // When
        var got = inputGraph
        var sideTable = GraphSideTable()
        _ = try await subject.map(graph: &got, sideTable: &sideTable)

        // Then
        XCTAssertEqual(
            got,
            outputGraph
        )
    }

    func test_map_when_one_of_the_binaries_fails_cannot_be_fetched() async throws {
        let path = try temporaryPath()
        let project = Project.test(path: path)

        // Given
        //
        //    App+----> B (Framework)+----> C (Framework)
        //
        let cFramework = Target.test(name: "C", platform: .iOS, product: .framework)
        let cGraphTarget = GraphTarget.test(path: path, target: cFramework)
        let cHash = "C"

        let bFramework = Target.test(name: "B", platform: .iOS, product: .framework)
        let bGraphTarget = GraphTarget.test(path: path, target: bFramework)
        let bHash = "B"
        let bXCFrameworkPath = path.appending(component: "B.xcframework")

        let app = Target.test(name: "App", platform: .iOS, product: .app)
        let appGraphTarget = GraphTarget.test(path: path, target: app)
        let appHash = "App"

        var inputGraph = Graph.test(
            name: "input",
            workspace: .test(),
            projects: [path: project],
            dependencies: [
                .target(name: bFramework.name, path: bGraphTarget.path): [
                    .target(name: cFramework.name, path: cGraphTarget.path),
                ],
                .target(name: app.name, path: appGraphTarget.path): [
                    .target(name: bFramework.name, path: bGraphTarget.path),
                ],
            ]
        )
        let outputGraph = Graph.test(
            name: "output",
            projects: inputGraph.projects,
            dependencies: inputGraph.dependencies
        )

        let contentHashes = [
            cGraphTarget.target.name: cHash,
            bGraphTarget.target.name: bHash,
            appGraphTarget.target.name: appHash,
        ]
        let error = TestError("error downloading C")


        let cache = MockCacheStorage()
        cache.existsStub = { name, hash in
            switch hash {
            case bHash:
                XCTAssertEqual(name, "B")
                return true
            case cHash:
                XCTAssertEqual(name, "C")
                return true
            default:
                return false
            }
        }

        cache.fetchStub = { name, hash in
            switch hash {
            case bHash:
                XCTAssertEqual(name, "B")
                return bXCFrameworkPath
            case cHash:
                XCTAssertEqual(name, "C")
                throw error
            default:
                XCTFail("Unexpected call to fetch")
                return "/"
            }
        }
        cacheGraphMutator.stubbedMapResult = outputGraph
        subject = TargetsToCacheBinariesGraphMapper(
            unsafe: false,
            hashesByCacheableTarget: contentHashes,
            cache: cache,
            cacheGraphMutator: cacheGraphMutator,
            clock: clock,
            timeTakenLoggerFormatter: formatter,
            logging: false
        )

        var sideTable = GraphSideTable()

        // Then
        await XCTAssertThrowsSpecific(
            try await subject.map(graph: &inputGraph, sideTable: &sideTable), 
            error
        )
    }
}
