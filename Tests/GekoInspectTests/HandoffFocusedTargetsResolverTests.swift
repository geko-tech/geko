import GekoGraph
import GekoGraphTesting
import GekoSupport
import GekoSupportTesting
import ProjectDescription
import XCTest

@testable import GekoInspect

final class HandoffFocusedTargetsResolverTests: GekoUnitTestCase {
    func test_resolveUsesExistingOwnershipRulesForChangedFiles() throws {
        let rootPath: AbsolutePath = "/repo"
        let files: [AbsolutePath] = [
            "/repo/App/One.swift",
            "/repo/App/Two.swift",
            "/repo/Framework/File.swift",
            "/repo/Shared.swift",
            "/repo/App/Deleted.swift",
            "/repo/Unknown.txt",
        ]
        let app = Target.test(
            name: "App",
            sources: ["/repo/App/**/*.swift", "/repo/Shared.swift"]
        )
        let framework = Target.test(
            name: "Framework",
            sources: ["/repo/Framework/**/*.swift", "/repo/Shared.swift"]
        )
        let graph = makeGraph(targets: [app, framework])
        let gitHandler = MockGitHandler()
        gitHandler.locallyChangedFilesStub = { _ in files }
        let subject = HandoffFocusedTargetsResolver(
            gitHandler: gitHandler,
            targetOwnershipResolver: TargetFileOwnershipResolver()
        )

        let result = try subject.resolve(graph: graph, rootPath: rootPath)

        XCTAssertEqual(gitHandler.locallyChangedFilesPath, rootPath)
        XCTAssertEqual(result.map(\.file), files)
        XCTAssertEqual(
            result.map { $0.targets.map(\.target.name) },
            [
                ["App"],
                ["App"],
                ["Framework"],
                ["App", "Framework"],
                ["App"],
                [],
            ])
    }

    func test_resolveReturnsEmptyOwnershipForCleanWorkingTree() throws {
        let gitHandler = MockGitHandler()
        gitHandler.locallyChangedFilesStub = { _ in [] }
        let subject = HandoffFocusedTargetsResolver(gitHandler: gitHandler)

        let result = try subject.resolve(graph: makeGraph(), rootPath: "/repo")

        XCTAssertEqual(result, [])
    }

    private func makeGraph(targets: [Target] = []) -> Graph {
        let project = Project.test(path: "/repo", sourceRootPath: "/repo", targets: targets)
        return .test(
            projects: [project.path: project],
            targets: [project.path: Dictionary(uniqueKeysWithValues: targets.map { ($0.name, $0) })]
        )
    }
}
