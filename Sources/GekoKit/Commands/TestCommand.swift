import ArgumentParser
import Foundation
import struct ProjectDescription.AbsolutePath
import GekoCore
import GekoSupport

public enum XcodeBuildPassthroughArgumentError: FatalError, Equatable {
      case alreadyHandled(String)

      public var description: String {
          switch self {
          case let .alreadyHandled(argument):
              "The argument \(argument) added after the terminator (--) cannot be passed through to xcodebuild because it is handled by Geko."
          }
      }

      public var type: ErrorType {
          switch self {
          case .alreadyHandled:
              .abort
          }
      }
  }

enum GekoTestFlagError: FatalError, Equatable {
      case invalidCombination([String])
      case passthroughActionVerbConflict(String)

      var description: String {
          switch self {
          case let .invalidCombination(arguments):
              "The arguments \(arguments.joined(separator: ", ")) are mutually exclusive, only of them can be used."
          case let .passthroughActionVerbConflict(verb):
              "The xcodebuild action '\(verb)' cannot be passed after the terminator (--). 'geko test' already picks the action based on its flags: 'test' by default, 'build-for-testing' with --build-only, and 'test-without-building' with --without-building. Drop '\(verb)' from the passthrough arguments, and use --build-only or --without-building if you need a different action."
          }
      }

      var type: ErrorType {
          switch self {
          case .invalidCombination, .passthroughActionVerbConflict:
              .abort
          }
      }
  }

  private let notAllowedPassthroughXcodeBuildArguments = [
      "-scheme",
      "-workspace",
      "-project",
      "-testPlan",
      "-skip-test-configuration",
      "-only-test-configuration",
      "-only-testing",
      "-skip-testing",
  ]

  private let xcodeBuildActionVerbs: Set<String> = [
      "test",
      "build-for-testing",
      "test-without-building",
  ]

/// Command that tests a target from the project in the current directory.
public struct TestCommand: AsyncParsableCommand, HasTrackableParameters {
    public init() {}

    public static var analyticsDelegate: TrackableParametersDelegate?

    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "test",
            abstract: "Tests a project"
        )
    }

    @Argument(
        help: "The scheme to be tested. By default it tests all the testable targets of the project in the current directory."
    )
    var scheme: String?

    @Flag(
        help: "[Deprecated] Force the generation of the project before testing."
    )
    var generate: Bool = false

    @Flag(
        name: .shortAndLong,
        help: "When passed, it cleans the project before testing it."
    )
    var clean: Bool = false

    @Option(
        name: .shortAndLong,
        help: "The path to the directory that contains the project to be tested."
    )
    var path: String?

    @Option(
        name: .shortAndLong,
        help: "Test on a specific device."
    )
    var device: String?

    @Option(
        name: .long,
        help: "Test on a specific platform."
    )
    var platform: String?

    @Option(
        name: .shortAndLong,
        help: "Test with a specific version of the OS."
    )
    var os: String?

    @Flag(
        name: .long,
        help: "When passed, append arch=x86_64 to the 'destination' to run simulator in a Rosetta mode."
    )
    var rosetta: Bool = false

    @Option(
        name: [.long, .customShort("C")],
        help: "The configuration to be used when testing the scheme."
    )
    var configuration: String?

    @Flag(
        name: .long,
        help: "When passed, it skips testing UI Tests targets."
    )
    var skipUITests: Bool = false

    @Option(
        name: [.long, .customShort("T")],
        help: "Path where test result bundle will be saved."
    )
    var resultBundlePath: String?

    @Option(
        help: "[Deprecated] Overrides the folder that should be used for derived data when testing a project."
    )
    var derivedDataPath: String?

    @Option(
        name: .long,
        help: "[Deprecated] Tests will retry <number> of times until success. Example: if 1 is specified, the test will be retried at most once, hence it will run up to 2 times."
    )
    var retryCount: Int = 0

    @Option(
        name: .long,
        help: "The test plan to run."
    )
    var testPlan: String?

    @Flag(
        name: .long,
        help: "When passed, it edits the list of test targets in the test plan and adds to this list the test targets passed via the --test-targets argument or adds all of them if the argument was not passed."
    )
    var editTestPlan: Bool = false

    @Option(
        name: .long,
        parsing: .upToNextOption,
        help: "The list of test identifiers you want to test. Expected format is TestTarget[/TestClass[/TestMethod]]. It is applied before --skip-testing",
        transform: TestIdentifier.init(string:)
    )
    var testTargets: [TestIdentifier] = []

    @Option(
        name: .long,
        parsing: .upToNextOption,
        help: "The list of test identifiers you want to skip testing. Expected format is TestTarget[/TestClass[/TestMethod]].",
        transform: TestIdentifier.init(string:)
    )
    var skipTestTargets: [TestIdentifier] = []

    @Option(
        name: .customLong("filter-configurations"),
        parsing: .upToNextOption,
        help: "The list of configurations you want to test. It is applied before --skip-configuration"
    )
    var configurations: [String] = []

    @Option(
        name: .long,
        parsing: .upToNextOption,
        help: "The list of configurations you want to skip testing."
    )
    var skipConfigurations: [String] = []

    @Flag(
        name: .long,
        help: "[Deprecated] When passed, it generates the project and skips testing. This is useful for debugging purposes."
    )
    var generateOnly: Bool = false

    @Flag(
        name: .long,
        help: "When passed, run the tests without building."
    )
    var withoutBuilding: Bool = false

    @Flag(
        name: .long,
        help: "When passed, build the tests, but don't run them"
    )
    var buildOnly: Bool = false

    @Argument(
        parsing: .postTerminator,
        help:
            "Arguments that will be passed through to xcodebuild. Use -- followed by xcodebuild arguments. Example: geko test -- -destination 'platform=iOS Simulator,name=iPhone 15' -parallel-testing-enabled YES"
    )
    var passthroughXcodeBuildArguments: [String] = []

    @OptionGroup
    var manifestOptions: ManifestOptions

    public func validate() throws {
        if withoutBuilding, buildOnly {
            throw TestServiceError.actionInvalid
        }

        try TestService().validateParameters(
            testTargets: testTargets,
            skipTestTargets: skipTestTargets
        )
    }

    public func run() async throws {
        try notAllowedPassthroughXcodeBuildArguments.forEach {
            if passthroughXcodeBuildArguments.contains($0) {
                throw XcodeBuildPassthroughArgumentError.alreadyHandled($0)
            }
        }

        if let firstPassthroughArgument = passthroughXcodeBuildArguments.first(where: { xcodeBuildActionVerbs.contains($0) }) {
            throw GekoTestFlagError.passthroughActionVerbConflict(firstPassthroughArgument)
        }

        if let derivedDataPath {
            logger.warning("--derivedDataPath is deprecated please use -derivedDataPath \(derivedDataPath) after the terminator (--) instead to passthrough parameters to xcodebuild")
        }
        if retryCount > 0 {
            logger.warning("--retryCount is deprecated please use -retry-tests-on-failure -test-iterations \(retryCount + 1) after the terminator (--) instead to passthrough parameters to xcodebuild")
        }

        try ManifestOptionsService()
            .load(options: manifestOptions, path: nil)

        let absolutePath: AbsolutePath

        if let path {
            absolutePath = try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath)
        } else {
            absolutePath = FileHandler.shared.currentPath
        }

        let action: XcodeBuildTestAction = if buildOnly {
            .build
        } else if withoutBuilding {
            .testWithoutBuilding
        } else {
            .test
        }

        try await TestService().run(
            schemeName: scheme,
            generate: generate,
            clean: clean,
            configuration: configuration,
            path: absolutePath,
            deviceName: device,
            platform: platform,
            osVersion: os,
            action: action,
            rosetta: rosetta,
            skipUITests: skipUITests,
            resultBundlePath: resultBundlePath.map {
                try AbsolutePath(
                    validating: $0,
                    relativeTo: FileHandler.shared.currentPath
                )
            },
            derivedDataPath: derivedDataPath,
            retryCount: retryCount,
            testTargets: testTargets,
            skipTestTargets: skipTestTargets,
            testPlanConfiguration: testPlan.map { testPlan in
                TestPlanConfiguration(
                    testPlan: testPlan,
                    configurations: configurations,
                    skipConfigurations: skipConfigurations
                )
            },
            validateTestTargetsParameters: false,
            generateOnly: generateOnly,
            passthroughXcodeBuildArguments: passthroughXcodeBuildArguments,
            editTestPlan: editTestPlan
        )
    }
}
