import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport
import XCTest
import XcbeautifyLib

@testable import GekoAutomation
@testable import GekoSupportTesting

final class XcodeBuildControllerTests: GekoUnitTestCase {
    private var subject: XcodeBuildController!
    private var formatter: Formatting!

    override func setUp() {
        super.setUp()
        formatter = MockFormatter()
        subject = XcodeBuildController(
            formatter: formatter,
            environment: environment,
            logFileStoreHandler: MockLogFileStoreHandler(path: fileHandler.currentPath),
            outputParser: XcodeBuildOutputParser(),
            isStructuredOutputEnabled: false
        )
    }

    override func tearDown() {
        subject = nil
        formatter = nil
        super.tearDown()
    }

    func test_build_without_device_id() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"

        var command = ["/usr/bin/xcrun", "xcodebuild", "clean", "build", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        system.succeedCommand(command, output: "output")

        // When
        try subject.build(
            target,
            scheme: scheme,
            destination: nil,
            rosetta: false,
            derivedDataPath: nil,
            clean: true,
            arguments: [],
            passthroughXcodeBuildArguments: [],
            eventHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_build_without_device_id_but_arch() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"

        var command = ["/usr/bin/xcrun", "xcodebuild", "clean", "build", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        system.succeedCommand(command, output: "output")

        // When
        try subject.build(
            target,
            scheme: scheme,
            destination: nil,
            rosetta: true,
            derivedDataPath: nil,
            clean: true,
            arguments: [],
            passthroughXcodeBuildArguments: [],
            eventHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_build_with_device_id() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"

        var command = ["/usr/bin/xcrun", "xcodebuild", "clean", "build", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        command.append(contentsOf: ["-destination", "id=this_is_a_udid"])
        system.succeedCommand(command, output: "output")

        // When
        try subject.build(
            target,
            scheme: scheme,
            destination: .device("this_is_a_udid"),
            rosetta: false,
            derivedDataPath: nil,
            clean: true,
            arguments: [],
            passthroughXcodeBuildArguments: [],
            eventHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_build_with_device_id_and_arch() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"

        var command = ["/usr/bin/xcrun", "xcodebuild", "clean", "build", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        command.append(contentsOf: ["-destination", "id=this_is_a_udid,arch=x86_64"])
        system.succeedCommand(command, output: "output")

        // When
        try subject.build(
            target,
            scheme: scheme,
            destination: .device("this_is_a_udid"),
            rosetta: true,
            derivedDataPath: nil,
            clean: true,
            arguments: [],
            passthroughXcodeBuildArguments: [],
            eventHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_build_with_arguments_derived_data_and_passthrough_arguments() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let derivedDataPath = path.appending(component: "DerivedData")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"

        var command = ["/usr/bin/xcrun", "xcodebuild", "build", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        command.append(contentsOf: ["-configuration", "Debug", "CODE_SIGNING_ALLOWED=NO"])
        command.append("ENABLE_TESTABILITY=YES")
        command.append(contentsOf: ["-derivedDataPath", derivedDataPath.pathString])
        system.succeedCommand(command, output: "output")

        // When
        try subject.build(
            target,
            scheme: scheme,
            destination: nil,
            rosetta: false,
            derivedDataPath: derivedDataPath,
            arguments: [.configuration("Debug"), .xcarg("CODE_SIGNING_ALLOWED", "NO")],
            passthroughXcodeBuildArguments: ["ENABLE_TESTABILITY=YES"],
            eventHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_test_when_device() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"

        var command = ["/usr/bin/xcrun", "xcodebuild", "clean", "test", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        command.append(contentsOf: ["-destination", "id=device-id"])
        system.succeedCommand(command, output: "output")

        // When
        try subject.test(
            target,
            scheme: scheme,
            clean: true,
            destination: .device("device-id"),
            action: .test,
            rosetta: false,
            derivedDataPath: nil,
            resultBundlePath: nil,
            arguments: [],
            retryCount: 0,
            testTargets: [],
            skipTestTargets: [],
            testPlanConfiguration: nil,
            passthroughXcodeBuildArguments: [],
            formattedLineHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_test_when_device_arch() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"

        var command = ["/usr/bin/xcrun", "xcodebuild", "clean", "test", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        command.append(contentsOf: ["-destination", "id=device-id,arch=x86_64"])
        system.succeedCommand(command, output: "output")

        // When
        try subject.test(
            target,
            scheme: scheme,
            clean: true,
            destination: .device("device-id"),
            action: .test,
            rosetta: true,
            derivedDataPath: nil,
            resultBundlePath: nil,
            arguments: [],
            retryCount: 0,
            testTargets: [],
            skipTestTargets: [],
            testPlanConfiguration: nil,
            passthroughXcodeBuildArguments: [],
            formattedLineHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_test_when_mac() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"

        var command = ["/usr/bin/xcrun", "xcodebuild", "clean", "test", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        command.append(contentsOf: ["-destination", "platform=macOS,arch=x86_64"])
        system.succeedCommand(command, output: "output")
        developerEnvironment.stubbedArchitecture = .x8664

        // When
        try subject.test(
            target,
            scheme: scheme,
            clean: true,
            destination: .mac,
            action: .test,
            rosetta: false,
            derivedDataPath: nil,
            resultBundlePath: nil,
            arguments: [],
            retryCount: 0,
            testTargets: [],
            skipTestTargets: [],
            testPlanConfiguration: nil,
            passthroughXcodeBuildArguments: [],
            formattedLineHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_test_with_derived_data() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"
        let derivedDataPath = try temporaryPath()

        var command = ["/usr/bin/xcrun", "xcodebuild", "clean", "test", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        command.append(contentsOf: ["-destination", "platform=macOS,arch=x86_64"])
        command.append(contentsOf: ["-derivedDataPath", derivedDataPath.pathString])
        system.succeedCommand(command, output: "output")
        developerEnvironment.stubbedArchitecture = .x8664

        // When
        try subject.test(
            target,
            scheme: scheme,
            clean: true,
            destination: .mac,
            action: .test,
            rosetta: false,
            derivedDataPath: derivedDataPath,
            resultBundlePath: nil,
            arguments: [],
            retryCount: 0,
            testTargets: [],
            skipTestTargets: [],
            testPlanConfiguration: nil,
            passthroughXcodeBuildArguments: [],
            formattedLineHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_test_with_result_bundle_path() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"
        let resultBundlePath = try temporaryPath()

        var command = ["/usr/bin/xcrun", "xcodebuild", "clean", "test", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        command.append(contentsOf: ["-destination", "platform=macOS,arch=x86_64"])
        command.append(contentsOf: ["-resultBundlePath", resultBundlePath.pathString])
        system.succeedCommand(command, output: "output")
        developerEnvironment.stubbedArchitecture = .x8664

        // When
        try subject.test(
            target,
            scheme: scheme,
            clean: true,
            destination: .mac,
            action: .test,
            rosetta: false,
            derivedDataPath: nil,
            resultBundlePath: resultBundlePath,
            arguments: [],
            retryCount: 0,
            testTargets: [],
            skipTestTargets: [],
            testPlanConfiguration: nil,
            passthroughXcodeBuildArguments: [],
            formattedLineHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_test_with_build_for_testing_action() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"

        var command = ["/usr/bin/xcrun", "xcodebuild", "build-for-testing", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        system.succeedCommand(command, output: "output")

        // When
        try subject.test(
            target,
            scheme: scheme,
            destination: nil,
            action: .build,
            rosetta: false,
            derivedDataPath: nil,
            resultBundlePath: nil,
            arguments: [],
            retryCount: 0,
            testTargets: [],
            skipTestTargets: [],
            testPlanConfiguration: nil,
            passthroughXcodeBuildArguments: [],
            formattedLineHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_test_with_test_without_building_action() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"

        var command = ["/usr/bin/xcrun", "xcodebuild", "test-without-building", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        system.succeedCommand(command, output: "output")

        // When
        try subject.test(
            target,
            scheme: scheme,
            destination: nil,
            action: .testWithoutBuilding,
            rosetta: false,
            derivedDataPath: nil,
            resultBundlePath: nil,
            arguments: [],
            retryCount: 0,
            testTargets: [],
            skipTestTargets: [],
            testPlanConfiguration: nil,
            passthroughXcodeBuildArguments: [],
            formattedLineHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_test_with_retry_filters_test_plan_and_passthrough_arguments() throws {
        // Given
        let path = try temporaryPath()
        let xcworkspacePath = path.appending(component: "Project.xcworkspace")
        let target = XcodeBuildTarget.workspace(xcworkspacePath)
        let scheme = "Scheme"
        let testTarget = try TestIdentifier(string: "AppTests/LoginTests/testLogin")
        let skippedTestTarget = try TestIdentifier(string: "AppTests/FlakyTests")

        var command = ["/usr/bin/xcrun", "xcodebuild", "test", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        command.append(contentsOf: ["-sdk", "iphonesimulator"])
        command.append("ENABLE_TESTABILITY=YES")
        command.append(contentsOf: ["-retry-tests-on-failure", "-test-iterations", "3"])
        command.append(contentsOf: ["-only-testing", testTarget.description])
        command.append(contentsOf: ["-skip-testing", skippedTestTarget.description])
        command.append(contentsOf: ["-testPlan", "MainPlan"])
        command.append(contentsOf: ["-only-test-configuration", "Default"])
        command.append(contentsOf: ["-skip-test-configuration", "Nightly"])
        system.succeedCommand(command, output: "output")

        // When
        try subject.test(
            target,
            scheme: scheme,
            destination: nil,
            action: .test,
            rosetta: false,
            derivedDataPath: nil,
            resultBundlePath: nil,
            arguments: [.sdk("iphonesimulator")],
            retryCount: 2,
            testTargets: [testTarget],
            skipTestTargets: [skippedTestTarget],
            testPlanConfiguration: TestPlanConfiguration(
                testPlan: "MainPlan",
                configurations: ["Default"],
                skipConfigurations: ["Nightly"]
            ),
            passthroughXcodeBuildArguments: ["ENABLE_TESTABILITY=YES"],
            formattedLineHandler: nil
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_archive() throws {
        // Given
        let path = try temporaryPath()
        let projectPath = path.appending(component: "Project.xcodeproj")
        let archivePath = path.appending(component: "Project.xcarchive")
        let derivedDataPath = path.appending(component: "DerivedData")
        let target = XcodeBuildTarget.project(projectPath)
        let scheme = "Scheme"

        var command = ["/usr/bin/xcrun", "xcodebuild", "clean", "archive", "-scheme", scheme]
        command.append(contentsOf: target.xcodebuildArguments)
        command.append(contentsOf: ["-archivePath", archivePath.pathString])
        command.append(contentsOf: ["-derivedDataPath", derivedDataPath.pathString])
        command.append(contentsOf: ["-configuration", "Release"])
        system.succeedCommand(command, output: "output")

        // When
        try subject.archive(
            target,
            scheme: scheme,
            clean: true,
            archivePath: archivePath,
            arguments: [.configuration("Release")],
            derivedDataPath: derivedDataPath
        )

        // Then
        XCTAssertTrue(system.called(command))
    }

    func test_create_xcframework() throws {
        // Given
        let path = try temporaryPath()
        let frameworkPath = path.appending(component: "App.framework")
        let outputPath = path.appending(component: "App.xcframework")
        let sanitizedFrameworkPath = frameworkPath.pathString.replacingOccurrences(
            of: "/var/",
            with: "/private/var/"
        )
        let command = [
            "/usr/bin/xcrun",
            "xcodebuild",
            "-create-xcframework",
            "-framework",
            sanitizedFrameworkPath,
            "-output",
            outputPath.pathString,
            "-allow-internal-distribution",
        ]
        system.succeedCommand(command, output: "output")

        // When
        try subject.createXCFramework(
            arguments: [.framework(frameworkPath: frameworkPath)],
            output: outputPath
        )

        // Then
        XCTAssertTrue(system.called(command))
    }
}

private struct MockFormatter: Formatting {
    func format(
        line _: String,
        output _: @escaping (String, XcbeautifyLib.OutputType) throws -> Void
    ) throws {}

    func format(_ line: String) -> String? {
        line
    }
}

private final class MockLogFileStoreHandler: LogFileStoreHandling {
    private let path: AbsolutePath

    init(path: AbsolutePath) {
        self.path = path
    }

    func createPath(logFile: LogFile, date _: Date) throws -> AbsolutePath {
        path.appending(component: logFile.rawValue)
    }

    func write(_: String, logFile _: LogFile) throws {}
    func close(logFile _: LogFile) throws {}
}
