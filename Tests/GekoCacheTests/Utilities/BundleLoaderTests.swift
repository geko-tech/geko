import struct ProjectDescription.AbsolutePath
import GekoSupport
import XCTest
@testable import GekoCache
@testable import GekoSupportTesting

final class BundleLoaderErrorTests: GekoUnitTestCase {
    func test_type_when_bundleNotFound() throws {
        // Given
        let path = try AbsolutePath(validating: "/bundles/geko.bundle")
        let subject = BundleLoaderError.bundleNotFound(path)

        // When
        let got = subject.type

        // Then
        XCTAssertEqual(got, .abort)
    }

    func test_description_when_bundleNotFound() throws {
        // Given
        let path = try AbsolutePath(validating: "/bundles/geko.bundle")
        let subject = BundleLoaderError.bundleNotFound(path)

        // When
        let got = subject.description

        // Then
        XCTAssertEqual(got, "Couldn't find bundle at \(path.pathString)")
    }
}

final class BundleLoaderTests: GekoUnitTestCase {
    var subject: BundleLoader!

    override func setUp() {
        super.setUp()
        subject = BundleLoader()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_load_when_the_framework_doesnt_exist() throws {
        // Given
        let path = try temporaryPath()
        let bundlePath = path.appending(component: "geko.bundle")

        // Then
        XCTAssertThrowsSpecific(try subject.load(path: bundlePath), BundleLoaderError.bundleNotFound(bundlePath))
    }

    func test_load_when_the_framework_exists() throws {
        // Given
        let path = try temporaryPath()
        let bundlePath = path.appending(component: "geko.bundle")

        try FileHandler.shared.touch(bundlePath)

        // When
        let got = try subject.load(path: bundlePath)

        // Then
        XCTAssertEqual(
            got,
            .bundle(path: bundlePath)
        )
    }
}
