import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoGraph
import GekoSupport
import XCTest

@testable import GekoCore
@testable import GekoCoreTesting
@testable import GekoSupportTesting

final class XCFrameworkLoaderErrorTests: GekoUnitTestCase {
    func test_type_when_xcframeworkNotFound() {
        // Given
        let subject = XCFrameworkLoaderError.xcframeworkNotFound("/frameworks/geko.xcframework")

        // Then
        XCTAssertEqual(subject.type, .abort)
    }

    func test_description_when_xcframeworkNotFound() {
        // Given
        let subject = XCFrameworkLoaderError.xcframeworkNotFound("/frameworks/geko.xcframework")

        // Then
        XCTAssertEqual(subject.description, "Couldn't find xcframework at /frameworks/geko.xcframework")
    }
}

final class XCFrameworkLoaderTests: GekoUnitTestCase {
    var xcframeworkMetadataProvider: MockXCFrameworkMetadataProvider!
    var subject: XCFrameworkLoader!

    override func setUp() {
        super.setUp()
        xcframeworkMetadataProvider = MockXCFrameworkMetadataProvider()
        subject = XCFrameworkLoader(xcframeworkMetadataProvider: xcframeworkMetadataProvider)
    }

    override func tearDown() {
        xcframeworkMetadataProvider = nil
        subject = nil
        super.tearDown()
    }

    func test_load_throws_when_the_xcframework_doesnt_exist() throws {
        // Given
        let path = try temporaryPath()
        let xcframeworkPath = path.appending(component: "geko.xcframework")

        // Then
        XCTAssertThrowsSpecific(
            try subject.load(path: xcframeworkPath, status: .required),
            XCFrameworkLoaderError.xcframeworkNotFound(xcframeworkPath)
        )
    }

    func test_load_when_the_xcframework_exists() throws {
        // Given
        let path = try temporaryPath()
        let xcframeworkPath = path.appending(component: "geko.xcframework")
        let binaryPath = path.appending(try RelativePath(validating: "geko.xcframework/whatever/geko"))
        let linking: BinaryLinking = .dynamic

        let infoPlist = XCFrameworkInfoPlist.test()
        try FileHandler.shared.touch(xcframeworkPath)

        xcframeworkMetadataProvider.loadMetadataStub = {
            XCFrameworkMetadata(
                path: $0,
                infoPlist: infoPlist,
                primaryBinaryPath: binaryPath,
                linking: linking,
                mergeable: false,
                status: .required,
                macroPath: nil
            )
        }

        // When
        let got = try subject.load(path: xcframeworkPath, status: .required)

        // Then
        XCTAssertEqual(
            got,
            .xcframework(
                GraphDependency.XCFramework(
                    path: xcframeworkPath,
                    infoPlist: infoPlist,
                    primaryBinaryPath: binaryPath,
                    linking: linking,
                    mergeable: false,
                    status: .required,
                    macroPath: nil
                )
            )
        )
    }
}
