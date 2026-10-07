import Crypto
import Foundation
import ProjectDescription
import XcodeProj

public extension [XCTestPlanDescriptor.TestTarget] {

    func mapTestTargets() -> [XCTestPlan.TestTarget] {
        map { target in
            XCTestPlan.TestTarget(
                target: XCTestPlan.TestTargetReference(
                    containerPath: target.containerPath,
                    identifier: target.pbxTarget.uuid,
                    name: target.pbxTarget.name
                ),
                selectedTests: target.selectedTests.isEmpty ? nil : target.selectedTests,
                skippedTests: target.skippedTests.isEmpty ? nil : target.skippedTests,
                enabled: target.isEnabled ? nil : false,
                parallelizable: target.isParallelizable ? true : nil,
            )
        }
    }
}

/// Describes a generated `.xctestplan` file.
public struct XCTestPlanDescriptor: Equatable {
    /// Configuration with resolved `targetForVariableExpansion`
    public struct Configuration: Equatable {
        public let configuration: GeneratedTestPlan.Configuration
        /// Test target used to expand variable references in `configuration.options`.
        public let targetForVariableExpansion: TestTarget?

        public init(configuration: GeneratedTestPlan.Configuration, targetForVariableExpansion: TestTarget?) {
            self.configuration = configuration
            self.targetForVariableExpansion = targetForVariableExpansion
        }
    }

    /// Absolute path where the generated `.xctestplan` will be written.
    public let path: AbsolutePath

    /// Configurations with resolved `targetForVariableExpansion`
    public let configurations: [Configuration]

    /// Options applied as the plan's global defaults, used when a configuration doesn't override them.
    public let defaultOptions: GeneratedTestPlan.Options?

    /// Test target used to expand variable references in `defaultOptions`.
    public let defaultOptionsTargetForVariableExpansion: TestTarget?

    /// Test targets included in the plan.
    public let testTargets: [TestTarget]

    public struct TestTarget: Equatable {
        /// Reference to the PBX target. Its `uuid` becomes the `identifier` in the test plan.
        public let pbxTarget: PBXTarget

        /// `container:` relative path to the `.xcodeproj` that owns the target, as used by Xcode.
        public let containerPath: String

        /// Whether the target runs or is skipped in the plan.
        public let isEnabled: Bool

        /// Whether the target isParallelizable.
        public let isParallelizable: Bool

        /// A list of specific tests to include in the plan.
        public let selectedTests: [String]

        /// A list of specific tests to exclude from the plan.
        public let skippedTests: [String]

        public init(
            pbxTarget: PBXTarget,
            containerPath: String,
            isEnabled: Bool,
            isParallelizable: Bool,
            selectedTests: [String],
            skippedTests: [String]
        ) {
            self.pbxTarget = pbxTarget
            self.containerPath = containerPath
            self.isEnabled = isEnabled
            self.isParallelizable = isParallelizable
            self.selectedTests = selectedTests
            self.skippedTests = skippedTests
        }
    }

    public init(
        path: AbsolutePath,
        configurations: [Configuration],
        defaultOptions: GeneratedTestPlan.Options?,
        defaultOptionsTargetForVariableExpansion: TestTarget?,
        testTargets: [TestTarget]
    ) {
        self.path = path
        self.configurations = configurations
        self.defaultOptions = defaultOptions
        self.defaultOptionsTargetForVariableExpansion = defaultOptionsTargetForVariableExpansion
        self.testTargets = testTargets
    }

    /// Encodes the descriptor into the Xcode `.xctestplan` JSON format.
    ///
    /// - Note: Must be called after the owning `.xcodeproj` has been written so that
    ///   `pbxTarget.uuid` returns stable blueprint identifiers.
    public func encode() throws -> Data {
        let plan = XCTestPlan(
            testTargets: testTargets.mapTestTargets(),
            configurations: configurations.map {
                XCTestPlan.Configuration(
                    id: configurationID(name: $0.configuration.name),
                    name: $0.configuration.name,
                    options: $0.configuration.options?.map(targetForVariableExpansion: $0.targetForVariableExpansion) ?? .empty
                )
            },
            defaultOptions: defaultOptions?.map(targetForVariableExpansion: defaultOptionsTargetForVariableExpansion) ?? .empty,
            version: 1
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(plan)
    }

    /// Deterministic UUID derived from the plan's absolute path.
    ///
    /// Keeps the configuration ID stable across regenerations (no git churn when a plan is
    /// pinned to a checked-in location) while being unique per plan.
    private func configurationID(name: String) -> UUID {
        let digest = Array(SHA256.hash(data: Data((path.pathString + name).utf8)).prefix(16))
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        ))
    }
}
