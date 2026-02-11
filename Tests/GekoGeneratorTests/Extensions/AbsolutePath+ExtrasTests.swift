import XCTest
import ProjectDescription
@testable import GekoGenerator

final class AbsolutePathOptimizedTests: XCTestCase {

    // MARK: - lastPathComponentFast

    func testLastPathComponent_singleRelative() {
        let path = AbsolutePath("/tmp").appending(component: "file")
        XCTAssertEqual(path.lastPathComponentFast, "file")
    }

    func testLastPathComponent_singleComponentRelative() {
        let path = AbsolutePath("/tmp").appending(component: "file")
        let relative = AbsolutePath(path.pathString)
        XCTAssertEqual(relative.lastPathComponentFast, "file")
    }

    func testLastPathComponent_onlyOneComponent_shouldReturnNil() {
        let path = AbsolutePath("/file")
        XCTAssertEqual(path.lastPathComponentFast, "file")
    }

    func testLastPathComponent_plainSingle_shouldReturnNil() {
        let single = AbsolutePath("only")
        XCTAssertNil(single.lastPathComponentFast)
    }

    func testLastPathComponent_nestedPath() {
        let path = AbsolutePath("/usr/local/bin")
        XCTAssertEqual(path.lastPathComponentFast, "bin")
    }

    func testLastPathComponent_trailingSlash() {
        let path = AbsolutePath("/usr/local/bin/")
        XCTAssertEqual(path.lastPathComponentFast, "bin")
    }

    func testLastPathComponent_rootOnly() {
        let path = AbsolutePath("/")
        XCTAssertNil(path.lastPathComponentFast)
    }

    func testLastPathComponent_multipleTrailingSlashes() {
        let path = AbsolutePath("/usr/local/bin////")
        XCTAssertEqual(path.lastPathComponentFast, "bin")
    }

    func testLastPathComponent_multipleInternalSlashes() {
        let path = AbsolutePath("/usr//local///bin")
        XCTAssertEqual(path.lastPathComponentFast, "bin")
    }

    func testLastPathComponent_onlySlashes() {
        let path = AbsolutePath("////")
        XCTAssertNil(path.lastPathComponentFast)
    }

    // MARK: - optimizedComponents

    func testOptimizedComponents_root() {
        let path = AbsolutePath("/")
        let result = Array(path.optimizedComponents)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].0, "/")
        XCTAssertTrue(result[0].1)
        XCTAssertEqual(path.components, result.map(\.0))
    }

    func testOptimizedComponents_nested() {
        let path = AbsolutePath("/usr/local/bin")
        let result = Array(path.optimizedComponents)

        XCTAssertEqual(result.map { $0.0 }, ["/", "usr", "local", "bin"])
        XCTAssertEqual(result.map { $0.1 }, [false, false, false, true])

        XCTAssertEqual(path.components, result.map(\.0))
    }

    func testOptimizedComponents_trailingSlash() {
        let path = AbsolutePath("/usr/local/bin/")
        let result = Array(path.optimizedComponents)

        XCTAssertEqual(result.map { $0.0 }, ["/", "usr", "local", "bin"])
        XCTAssertEqual(result.map { $0.1 }, [false, false, false, true])

        XCTAssertEqual(path.components, result.map(\.0))
    }

    func testOptimizedComponents_multipleSlashes() {
        let path = AbsolutePath("/usr//local///bin")
        let result = Array(path.optimizedComponents)

        XCTAssertEqual(result.map { $0.0 }, ["/", "usr", "local", "bin"])
        XCTAssertEqual(result.map { $0.1 }, [false, false, false, true])

        XCTAssertEqual(path.components, result.map(\.0))
    }

    func testOptimizedComponents_relative() {
        let path = AbsolutePath("dir/subdir/file")
        let result = Array(path.optimizedComponents)

        XCTAssertEqual(result.map { $0.0 }, ["dir", "subdir", "file"])
        XCTAssertEqual(result.map { $0.1 }, [false, false, true])

        XCTAssertEqual(path.components, result.map(\.0))
    }

    func testOptimizedComponents_singleRelative() {
        let path = AbsolutePath("file")
        let result = Array(path.optimizedComponents)

        XCTAssertEqual(result.map { $0.0 }, ["file"])
        XCTAssertEqual(result.map { $0.1 }, [true])

        XCTAssertEqual(path.components, result.map(\.0))
    }

    func testOptimizedComponents_onlySlashes() {
        let path = AbsolutePath("////")
        let result = Array(path.optimizedComponents)

        XCTAssertEqual(result.map { $0.0 }, ["/"])
        XCTAssertEqual(result.map { $0.1 }, [true])

        XCTAssertEqual(path.components, result.map(\.0))
    }

    func testOptimizedComponents_empty() {
        let path = AbsolutePath("")
        let result = Array(path.optimizedComponents)

        XCTAssertEqual(path.components, result.map(\.0))
    }
}
