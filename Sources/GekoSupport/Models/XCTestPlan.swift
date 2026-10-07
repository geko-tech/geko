
import Foundation
import ProjectDescription

public struct XCTestPlan: Codable, Equatable, Sendable {
    public struct Options: Codable, Equatable, Sendable {
        public struct MallocStackLoggingOptions: Codable, Equatable, Sendable {
            public enum LoggingType: String, Codable, Equatable, Sendable {
                case liveAllocations
            }

            enum CodingKeys: String, CodingKey {
                case loggingType
            }

            public var loggingType: LoggingType?

            public init(loggingType: LoggingType?) {
                self.loggingType = loggingType
            }

            public static func on() -> Self { Self(loggingType: .liveAllocations) }
            public static func off() -> Self? { nil }
        }

        public let commandLineArgumentEntries: [GeneratedTestPlan.Options.CommandLineArgumentEntry]?
        public let environmentVariableEntries: [GeneratedTestPlan.Options.VariableEntity]?
        public let targetForVariableExpansion: TestTargetReference?
        public let language: String?
        public let region: String?
        public let locationScenario: GeneratedTestPlan.Options.LocationScenario?
        public let uiTestingScreenshotsLifetime: GeneratedTestPlan.Options.UITestingScreenshotsLifetime?
        public let preferredScreenCaptureFormat: GeneratedTestPlan.Options.PreferredScreenCaptureFormat?
        public let areLocalizationScreenshotsEnabled: Bool?
        public let distributor: GeneratedTestPlan.Options.Distributor?
        public let userAttachmentLifetime: GeneratedTestPlan.Options.UserAttachmentLifetime?
        public let diagnosticCollectionPolicy: GeneratedTestPlan.Options.DiagnosticCollectionPolicy?
        public let testExecutionOrdering:  GeneratedTestPlan.Options.TestExecutionOrdering?
        public let testTimeoutsEnabled: Bool?
        public let defaultTestExecutionTimeAllowance: Int?
        public let maximumTestExecutionTimeAllowance: Int?
        public let testRepetitionMode: GeneratedTestPlan.Options.TestRepetitionMode?
        public let maximumTestRepetitions: Int?
        public let repeatInNewRunnerProcess: Bool?
        public let codeCoverage: Bool?
        public let addressSanitizer: GeneratedTestPlan.Options.AddressSanitizer?
        public let threadSanitizerEnabled: Bool?
        public let undefinedBehaviorSanitizerEnabled: Bool?
        public let mainThreadCheckerDetectionPolicy: GeneratedTestPlan.Options.RuntimeApiChecking?
        public let threadPerformanceCheckerRuntimeIssueDetection: GeneratedTestPlan.Options.RuntimeApiChecking?
        public let runtimeIssueDetection: GeneratedTestPlan.Options.RuntimeApiChecking?
        public let checkedAllocations: GeneratedTestPlan.Options.CheckedAllocations?
        public let mallocScribbleEnabled: Bool?
        public let mallocGuardEdgesEnabled: Bool?
        public let nsZombieEnabled: Bool?
        public let mallocStackLoggingOptions: MallocStackLoggingOptions?

        public init(
            commandLineArgumentEntries: [GeneratedTestPlan.Options.CommandLineArgumentEntry]?,
            environmentVariableEntries: [GeneratedTestPlan.Options.VariableEntity]?,
            targetForVariableExpansion: TestTargetReference?,
            language: String?,
            region: String?,
            locationScenario: GeneratedTestPlan.Options.LocationScenario?,
            uiTestingScreenshotsLifetime: GeneratedTestPlan.Options.UITestingScreenshotsLifetime?,
            preferredScreenCaptureFormat: GeneratedTestPlan.Options.PreferredScreenCaptureFormat?,
            areLocalizationScreenshotsEnabled: Bool?,
            distributor: GeneratedTestPlan.Options.Distributor?,
            userAttachmentLifetime: GeneratedTestPlan.Options.UserAttachmentLifetime?,
            diagnosticCollectionPolicy: GeneratedTestPlan.Options.DiagnosticCollectionPolicy?,
            testExecutionOrdering: GeneratedTestPlan.Options.TestExecutionOrdering?,
            testTimeoutsEnabled: Bool?,
            defaultTestExecutionTimeAllowance: Int?,
            maximumTestExecutionTimeAllowance: Int?,
            testRepetitionMode: GeneratedTestPlan.Options.TestRepetitionMode?,
            maximumTestRepetitions: Int?,
            repeatInNewRunnerProcess: Bool?,
            codeCoverage: Bool?,
            addressSanitizer: GeneratedTestPlan.Options.AddressSanitizer?,
            threadSanitizerEnabled: Bool?,
            undefinedBehaviorSanitizerEnabled: Bool?,
            mainThreadCheckerDetectionPolicy: GeneratedTestPlan.Options.RuntimeApiChecking?,
            threadPerformanceCheckerRuntimeIssueDetection: GeneratedTestPlan.Options.RuntimeApiChecking?,
            runtimeIssueDetection: GeneratedTestPlan.Options.RuntimeApiChecking?,
            checkedAllocations: GeneratedTestPlan.Options.CheckedAllocations?,
            mallocScribbleEnabled: Bool?,
            mallocGuardEdgesEnabled: Bool?,
            nsZombieEnabled: Bool?,
            mallocStackLoggingOptions: MallocStackLoggingOptions?,
        ) {
            self.commandLineArgumentEntries = commandLineArgumentEntries
            self.environmentVariableEntries = environmentVariableEntries
            self.targetForVariableExpansion = targetForVariableExpansion
            self.language = language
            self.region = region
            self.locationScenario = locationScenario
            self.uiTestingScreenshotsLifetime = uiTestingScreenshotsLifetime
            self.preferredScreenCaptureFormat = preferredScreenCaptureFormat
            self.areLocalizationScreenshotsEnabled = areLocalizationScreenshotsEnabled
            self.distributor = distributor
            self.userAttachmentLifetime = userAttachmentLifetime
            self.diagnosticCollectionPolicy = diagnosticCollectionPolicy
            self.testExecutionOrdering = testExecutionOrdering
            self.testTimeoutsEnabled = testTimeoutsEnabled
            self.defaultTestExecutionTimeAllowance = defaultTestExecutionTimeAllowance
            self.maximumTestExecutionTimeAllowance = maximumTestExecutionTimeAllowance
            self.testRepetitionMode = testRepetitionMode
            self.maximumTestRepetitions = maximumTestRepetitions
            self.repeatInNewRunnerProcess = repeatInNewRunnerProcess
            self.codeCoverage = codeCoverage
            self.addressSanitizer = addressSanitizer
            self.threadSanitizerEnabled = threadSanitizerEnabled
            self.undefinedBehaviorSanitizerEnabled = undefinedBehaviorSanitizerEnabled
            self.mainThreadCheckerDetectionPolicy = mainThreadCheckerDetectionPolicy
            self.threadPerformanceCheckerRuntimeIssueDetection = threadPerformanceCheckerRuntimeIssueDetection
            self.runtimeIssueDetection = runtimeIssueDetection
            self.checkedAllocations = checkedAllocations
            self.mallocScribbleEnabled = mallocScribbleEnabled
            self.mallocGuardEdgesEnabled = mallocGuardEdgesEnabled
            self.nsZombieEnabled = nsZombieEnabled
            self.mallocStackLoggingOptions = mallocStackLoggingOptions
        }

        static let empty = Self(
            commandLineArgumentEntries: nil,
            environmentVariableEntries: nil,
            targetForVariableExpansion: nil,
            language: nil,
            region: nil,
            locationScenario: nil,
            uiTestingScreenshotsLifetime: nil,
            preferredScreenCaptureFormat: nil,
            areLocalizationScreenshotsEnabled: nil,
            distributor: nil,
            userAttachmentLifetime: nil,
            diagnosticCollectionPolicy: nil,
            testExecutionOrdering: nil,
            testTimeoutsEnabled: nil,
            defaultTestExecutionTimeAllowance: nil,
            maximumTestExecutionTimeAllowance: nil,
            testRepetitionMode: nil,
            maximumTestRepetitions: nil,
            repeatInNewRunnerProcess: nil,
            codeCoverage: nil,
            addressSanitizer: nil,
            threadSanitizerEnabled: nil,
            undefinedBehaviorSanitizerEnabled: nil,
            mainThreadCheckerDetectionPolicy: nil,
            threadPerformanceCheckerRuntimeIssueDetection: nil,
            runtimeIssueDetection: nil,
            checkedAllocations: nil,
            mallocScribbleEnabled: nil,
            mallocGuardEdgesEnabled: nil,
            nsZombieEnabled: nil,
            mallocStackLoggingOptions: nil,
        )
    }

    public struct Configuration: Codable, Equatable, Sendable {
        public let id: UUID
        public let name: String
        public let options: Options?

        public init(id: UUID, name: String, options: Options? = nil) {
            self.id = id
            self.name = name
            self.options = options
        }
    }

    public struct TestTargetReference: Codable, Equatable, Sendable {
        /// Path to the target's container, prefixed with `container:` (e.g. `container:App.xcodeproj`).
        public var containerPath: String

        /// Blueprint identifier of the PBX target the entry references.
        public let identifier: String

        /// Name of the test target.
        public let name: String

        public init(containerPath: String, identifier: String, name: String) {
            self.containerPath = containerPath
            self.identifier = identifier
            self.name = name
        }

        public func projectPath() -> String? {
            let containerInfo = containerPath.split(separator: ":")
            switch containerInfo.count {
            case 1:
                return containerPath
            case 2 where containerInfo[0] == "container":
                return String(containerInfo[1])
            default:
                return nil
            }
        }
    }

    public struct TestTarget: Codable, Equatable, Sendable {
        /// Whether the target runs. Omitted in the JSON when `true`; Xcode defaults to enabled.
        public var enabled: Bool?

        /// Whether the target runs in parallel with other targets.
        public var parallelizable: Bool?

        /// A list of specific tests to include in the plan.
        public var selectedTests: [String]?

        /// A list of specific tests to exclude from the plan.
        public var skippedTests: [String]?

        public var target: TestTargetReference

        public init(
            target: TestTargetReference,
            selectedTests: [String]? = nil,
            skippedTests: [String]? = nil,
            enabled: Bool? = nil,
            parallelizable: Bool? = nil
        ) {
            self.enabled = enabled
            self.selectedTests = selectedTests
            self.skippedTests = skippedTests
            self.parallelizable = parallelizable
            self.target = target
        }
    }

    public var configurations: [Configuration]?
    public var defaultOptions: Options?
    public var testTargets: [TestTarget]
    public let version: Int?

    public init(
        testTargets: [TestTarget],
        configurations: [Configuration]? = nil,
        defaultOptions: Options? = nil,
        version: Int? = nil
    ) {
        self.configurations = configurations
        self.defaultOptions = defaultOptions
        self.testTargets = testTargets
        self.version = version
    }
}
