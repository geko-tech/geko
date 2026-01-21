import GekoCore
import GekoGraph
import ProjectDescription
import XCTest
@testable import GekoCache
@testable import GekoCoreTesting
@testable import GekoGraphTesting
@testable import GekoSupportTesting

final class CacheGraphLinterTests: GekoUnitTestCase {
    var subject: CacheGraphLinter!

    override func setUp() {
        super.setUp()
        subject = CacheGraphLinter()
    }

    func test_lint() {
        // Given
        let profile = ProjectDescription.Cache.Profile(name: "Development", configuration: "Debug", platforms: [.iOS: .options(arch: .arm64)])
        let project = Project.test()
        let target = Target.test(scripts: [
            .init(name: "test", order: .post, script: .embedded("echo 'Hello World'")),
        ])
        let graphTarget = GraphTarget.test(
            path: project.path,
            target: target,
            project: project
        )
        let graph = Graph.test(
            projects: [project.path: project],
            targets: [
                graphTarget.path: [graphTarget.target.name: graphTarget.target],
            ]
        )

        // When
        subject.lint(graph: graph, cacheProfile: profile)

        // Then
        XCTAssertPrinterOutputContains("""
        The following targets contain scripts that might introduce non-cacheable side-effects
        """)
    }
    
    func test_lint_with_allowed_scripts() {
        // Given
        let profile = ProjectDescription.Cache.Profile(
            name: "Development",
            configuration: "Debug",
            platforms: [.iOS: .options(arch: .arm64)],
            scripts: [.init(name: "Test", envKeys: [])]
        )
        let project = Project.test()
        let target = Target.test(scripts: [
            .init(name: "Test", order: .post, script: .embedded("echo 'Hello World'")),
        ])
        let graphTarget = GraphTarget.test(
            path: project.path,
            target: target,
            project: project
        )
        let graph = Graph.test(
            projects: [project.path: project],
            targets: [
                graphTarget.path: [graphTarget.target.name: graphTarget.target],
            ]
        )

        // When
        subject.lint(graph: graph, cacheProfile: profile)
        
        XCTAssertPrinterOutputNotContains("""
        The following targets contain scripts that might introduce non-cacheable side-effects
        """)
    }
}
