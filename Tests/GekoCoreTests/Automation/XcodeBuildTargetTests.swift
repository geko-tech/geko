import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport
import XCTest

@testable import GekoSupportTesting

final class XcodeBuildTargetTests: GekoUnitTestCase {
    func test_xcodebuildArguments_returns_the_right_arguments_when_project() throws {
        // Given
        let path = try temporaryPath()
        let xcodeprojPath = path.appending(component: "Project.xcodeproj")
        let subject = XcodeBuildTarget.project(xcodeprojPath)

        // When
        let got = subject.xcodebuildArguments

        // Then
        XCTAssertEqual(got, ["-project", xcodeprojPath.pathString])
    }

    func test_xcodebuildArguments_returns_the_right_arguments_when_workspace() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let subject = XcodeBuildTarget.workspace(xcworkspacePath)

        // When
        let got = subject.xcodebuildArguments

        // Then
        XCTAssertEqual(got, ["-workspace", xcworkspacePath.pathString])
    }
}
