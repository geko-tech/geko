import Foundation
import GekoCore
import GekoCoreTesting
import GekoGraph
import ProjectDescription
import XCTest
import GekoSupport

@testable import GekoCache
@testable import GekoSupportTesting

final class XCFrameworksContentHasherTests: GekoUnitTestCase {
    private var subject: XCFrameworksContentHasher!
    private var xcframeworkMetadataProvider: MockXCFrameworkMetadataProvider!
    private var filePath1: AbsolutePath! = try! AbsolutePath(validating: "/file1/FooFramework.xcframework")
    private var filePath2: AbsolutePath! = try! AbsolutePath(validating: "/file2/BarFramework.xcframework")
    private var source1: SourceFiles!
    private var source2: SourceFiles!

    override func setUp() {
        super.setUp()
        do {
            let temporaryDirectoryPath = try temporaryPath()
            source1 = try createTemporarySourceFile(on: temporaryDirectoryPath, name: "1", content: "1")
            source2 = try createTemporarySourceFile(on: temporaryDirectoryPath, name: "2", content: "2")
        } catch {
            XCTFail("Error while creating files for stub project")
        }
        xcframeworkMetadataProvider = MockXCFrameworkMetadataProvider()
        subject = XCFrameworksContentHasher(
            contentHasher: ContentHasher(),
            additionalCacheStringsHasher: AdditionalCacheStringsHasher(),
            xcframeworkMetadataProvider: xcframeworkMetadataProvider
        )
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_xcframeworksHashesh_swiftmoduleCacheDisabled() throws {
        // Given
        let graph = Graph.test()
        let profile = Cache.Profile.test()

        // When
        let hashes = try subject.contentHashes(
            for: graph,
            cacheProfile: profile,
            cacheUserVersion: nil,
            cacheOutputType: .framework,
            cacheDestination: .simulator
        )

        // Then
        XCTAssertEqual(hashes, [:])
    }

    func test_xcframeworksHashesh_emptyGraph() throws {
        // Given
        let graph = Graph.test()
        let profile = Cache.Profile.test(options: .options(swiftModuleCacheEnabled: true))
        system.swiftlangVersionStub = { "6.0.0" }

        // When
        let hashes = try subject.contentHashes(
            for: graph,
            cacheProfile: profile,
            cacheUserVersion: nil,
            cacheOutputType: .framework,
            cacheDestination: .simulator
        )

        // Then
        XCTAssertEqual(hashes, [:])
    }

    func test_xcframeworksHashes_returnsExpectedResult() throws {
        // Given
        let expectedHashes = [
            filePath1: "de1c9c5c1735fa98", // FooFramework
            filePath2: "16b9097ab14ecec9", // BarFramework
        ]

        xcframeworkMetadataProvider.swiftModuleFolderPathStub = try temporaryPath()

        let profile = Cache.Profile.test(options: .options(swiftModuleCacheEnabled: true))
        system.swiftlangVersionStub = { "6.0.0" }

        let xcframework1 = GraphDependency.testXCFramework(path: filePath1)
        let xcframework2 = GraphDependency.testXCFramework(path: filePath2)

        let externalDependenciesGraph = DependenciesGraph(
            externalDependencies: [:],
            externalProjects: [:],
            externalFrameworkDependencies: [:],
            tree: [
                "FooFramework": GekoGraph.DependenciesGraph.TreeDependency(version: "1.0.0", dependencies: []),
                "BarFramework": GekoGraph.DependenciesGraph.TreeDependency(version: "3.0.0", dependencies: [])
            ]
        )

        let project1 = Project.test(path: try temporaryPath().appending(component: "f1"))
        let project2 = Project.test(path: try temporaryPath().appending(component: "f2"))
        let framework1 = makeFramework(project: project1, sources: [source1, source2])
        let framework2 = makeFramework(project: project2, sources: [source2, source1])
        let graph = Graph.test(
            projects: [
                project1.path: project1,
                project2.path: project2,
            ],
            targets: [
                project1.path: [
                    framework1.target.name: framework1.target,
                ],
                project2.path: [
                    framework2.target.name: framework2.target,
                ],
            ], xcframeworks: [
                filePath1: xcframework1,
                filePath2: xcframework2
            ],
            externalDependenciesGraph: externalDependenciesGraph
        )

        // When

        let hashes = try subject.contentHashes(
            for: graph,
            cacheProfile: profile,
            cacheUserVersion: nil,
            cacheOutputType: .framework,
            cacheDestination: .simulator
        )

        // Then
        XCTAssertEqual(hashes, expectedHashes)
    }

    private func makeFramework(
        project: Project,
        platform: Platform = .iOS,
        productName: String? = nil,
        sources: [SourceFiles] = [],
        resources: [ResourceFileElement] = [],
        coreDataModels: [CoreDataModel] = [],
        targetScripts: [TargetScript] = []
    ) -> GraphTarget {
        GraphTarget.test(
            path: project.path,
            target: .test(
                platform: platform,
                product: .framework,
                productName: productName,
                sources: sources,
                resources: resources,
                coreDataModels: coreDataModels,
                scripts: targetScripts
            ),
            project: project
        )
    }

    private func createTemporarySourceFile(
        on temporaryDirectoryPath: AbsolutePath,
        name: String,
        content: String
    ) throws -> SourceFiles {
        let filePath = temporaryDirectoryPath.appending(component: name)
        try FileHandler.shared.touch(filePath)
        try FileHandler.shared.write(content, path: filePath, atomically: true)
        return SourceFiles(glob: filePath, compilerFlags: nil)
    }
}
