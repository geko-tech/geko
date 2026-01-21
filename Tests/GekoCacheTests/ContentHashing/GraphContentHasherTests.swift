import Foundation
import GekoCore
import GekoCoreTesting
import GekoGraph
import ProjectDescription
import XCTest

@testable import GekoCache
@testable import GekoSupportTesting

final class GraphContentHasherTests: GekoUnitTestCase {
    private var subject: GraphContentHasher!

    override func setUp() {
        super.setUp()
        subject = GraphContentHasher(contentHasher: ContentHasher())
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_contentHashes_emptyGraph() throws {
        // Given
        let graph = Graph.test()
        let profile = ProjectDescription.Cache.Profile(name: "Development", configuration: "Debug", platforms: [.iOS: .options(arch: .arm64)])

        // When
        let hashes = try subject.contentHashes(
            for: graph,
            cacheProfile: profile,
            filter: { _ in true },
            additionalStrings: [],
            unsafe: false
        )

        // Then
        XCTAssertEqual(hashes, Dictionary())
    }

    func test_contentHashes_returnsOnlyFrameworks() throws {
        // Given
        let path: AbsolutePath = "/project"
        let project: Project = .test(
            path: path
        )
        let frameworkTarget = GraphTarget.test(
            path: path,
            target: .test(
                name: "FrameworkA",
                product: .framework,
                infoPlist: nil,
                entitlements: nil
            ),
            project: .test(path: path)
        )
        let secondFrameworkTarget = GraphTarget.test(
            path: path,
            target: .test(
                name: "FrameworkB",
                product: .framework,
                infoPlist: nil,
                entitlements: nil
            ),
            project: .test(path: path)
        )
        let appTarget = GraphTarget.test(
            path: path,
            target: .test(
                name: "App",
                product: .app,
                infoPlist: nil,
                entitlements: nil
            ),
            project: .test(path: path)
        )
        let dynamicLibraryTarget = GraphTarget.test(
            path: path,
            target: .test(
                name: "DynamicLibrary",
                product: .dynamicLibrary,
                infoPlist: nil,
                entitlements: nil
            ),
            project: .test(path: path)
        )
        let staticFrameworkTarget = GraphTarget.test(
            path: path,
            target: .test(
                name: "StaticFramework",
                product: .staticFramework,
                infoPlist: nil,
                entitlements: nil
            ),
            project: .test(path: path)
        )

        let graph = Graph.test(
            path: path,
            projects: [project.path: project],
            targets: [
                path: [
                    frameworkTarget.target.name: frameworkTarget.target,
                    secondFrameworkTarget.target.name: secondFrameworkTarget.target,
                    appTarget.target.name: appTarget.target,
                    dynamicLibraryTarget.target.name: dynamicLibraryTarget.target,
                    staticFrameworkTarget.target.name: staticFrameworkTarget.target,
                ],
            ]
        )
        let profile = ProjectDescription.Cache.Profile(name: "Development", configuration: "Debug", platforms: [.iOS: .options(arch: .arm64)])

        let expectedCachableTargets = [frameworkTarget.target.name, secondFrameworkTarget.target.name].sorted()

        // When
        let hashes = try subject.contentHashes(
            for: graph,
            cacheProfile: profile,
            filter: {
                $0.target.product == .framework
            },
            additionalStrings: [],
            unsafe: false
        )

        // Then
        XCTAssertEqual(hashes.keys.sorted(), expectedCachableTargets)
    }
}
