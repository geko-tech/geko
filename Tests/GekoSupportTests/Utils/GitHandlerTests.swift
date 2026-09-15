import ProjectDescription
import XCTest

@testable import GekoSupport
@testable import GekoSupportTesting

final class GitHandlerTests: GekoUnitTestCase {
    private var subject: GitHandler!

    override func setUp() {
        super.setUp()
        subject = GitHandler(system: system)
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_cloneInto() throws {
        let url = "https://some/url/to/repo.git"
        let path = try temporaryPath()

        system.stubs["git -C \(path.pathString) clone \(url)"] = (stderror: nil, stdout: nil, exitstatus: 0)

        XCTAssertNoThrow(try subject.clone(url: url, into: path))
        XCTAssertTrue(system.called(["git", "-C", path.pathString, "clone", url]))
    }

    func test_cloneTo() throws {
        let url = "https://some/url/to/repo.git"

        system.stubs["git clone \(url)"] = (stderror: nil, stdout: nil, exitstatus: 0)

        XCTAssertNoThrow(try subject.clone(url: url))
        XCTAssertTrue(system.called(["git", "clone", url]))
    }

    func test_cloneTo_WITH_path() throws {
        let url = "https://some/url/to/repo.git"
        let path = try temporaryPath()

        system.stubs["git clone \(url) \(path.pathString)"] = (stderror: nil, stdout: nil, exitstatus: 0)

        XCTAssertNoThrow(try subject.clone(url: url, to: path))
        XCTAssertTrue(system.called(["git", "clone", url, path.pathString]))
    }

    func test_checkout() throws {
        let id = "main"

        system.stubs["git checkout \(id)"] = (stderror: nil, stdout: nil, exitstatus: 0)

        XCTAssertNoThrow(try subject.checkout(id: id, in: nil))
    }

    func test_checkout_WITH_path() throws {
        let id = "main"
        let path = try temporaryPath()

        let expectedCommand = [
            "git",
            "--git-dir",
            path.appending(component: ".git").pathString,
            "--work-tree",
            path.pathString,
            "checkout",
            id,
        ].joined(separator: " ")

        system.stubs[expectedCommand] = (stderror: nil, stdout: nil, exitstatus: 0)

        XCTAssertNoThrow(try subject.checkout(id: id, in: path))
        XCTAssertTrue(system.called([
            "git",
            "--git-dir",
            path.appending(component: ".git").pathString,
            "--work-tree",
            path.pathString,
            "checkout",
            id,
        ]))
    }

    func test_parsed_versions() throws {
        let url = "https://some/url/to/repo.git"

        let expectedCommand = [
            "git",
            "ls-remote",
            "-t",
            "--sort=v:refname",
            url,
        ]

        let output = """
            4e4230bb95e1c57e82a1e5f9b4c79486fc2543fb    refs/tags/1.9.0
            There are no versions on this line.
            d265964d42bb934783246c3158297592b4977c3c    refs/tags/1.52.0
            5e17254d4a3c14454ecab6575b4a44d6685d3865    refs/tags/2.0.0
        """

        let expectedResult = [Version(1, 9, 0), Version(1, 52, 0), Version(2, 0, 0)]

        system.stubs[expectedCommand.joined(separator: " ")] = (stderror: nil, stdout: output, exitstatus: 0)

        let result = try subject.remoteTaggedVersions(url: url)

        XCTAssertTrue(system.called(expectedCommand))
        XCTAssertEqual(result, expectedResult)
    }

    func test_locallyChangedFiles_usesRequestedPathAndDeduplicatesSortedPaths() throws {
        let projectPath: AbsolutePath = "/repo/Projects/App"
        let repositoryCheckCommand = [
            "git", "-C", projectPath.pathString,
            "rev-parse", "--is-inside-work-tree",
        ]
        let trackedCommand = [
            "git", "-C", projectPath.pathString,
            "diff", "HEAD", "--name-only", "--no-renames", "--relative", "-z", "--", ".",
        ]
        let untrackedCommand = [
            "git", "-C", projectPath.pathString,
            "ls-files", "--others", "--exclude-standard", "-z", "--", ".",
        ]
        system.succeedCommand(repositoryCheckCommand, output: "true\n")
        system.succeedCommand(trackedCommand, output: "Sources/B.swift\0Sources/A.swift\0")
        system.succeedCommand(untrackedCommand, output: "Sources/A.swift\0Sources/Новый файл.swift\0")

        let result = try subject.locallyChangedFiles(in: projectPath)

        XCTAssertEqual(result, [
            "/repo/Projects/App/Sources/A.swift",
            "/repo/Projects/App/Sources/B.swift",
            "/repo/Projects/App/Sources/Новый файл.swift",
        ])
        XCTAssertTrue(system.called(trackedCommand))
        XCTAssertTrue(system.called(untrackedCommand))
    }

    func test_locallyChangedFiles_returnsEmptyWhenPathIsNotInGitWorkingTree() throws {
        let path: AbsolutePath = "/project"
        let repositoryCheckCommand = [
            "git", "-C", path.pathString,
            "rev-parse", "--is-inside-work-tree",
        ]
        system.errorCommand(repositoryCheckCommand, error: "fatal: not a git repository")

        XCTAssertEqual(try subject.locallyChangedFiles(in: path), [])
    }
}
