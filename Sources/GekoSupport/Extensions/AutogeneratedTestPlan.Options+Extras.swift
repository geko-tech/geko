import ProjectDescription

extension GeneratedTestPlan.Options {

    public func map(
        targetForVariableExpansion: XCTestPlan.TestTargetReference?,
        codeCoverageTargets: [XCTestPlan.TestTargetReference]
    ) -> XCTestPlan.Options {

        let convertedMallocStackLoggingOptions: XCTestPlan.Options.MallocStackLoggingOptions? = {
            switch mallocStackLoggingOptions {
            case .on: .on()
            case .off, .none: nil
            }
        }()

        let codeCoverageMapped: XCTestPlan.Options.Coverage? = {
            switch codeCoverage {
            case .all, .none: nil
            case .disabled: .disabled
            case .selected: .targets(codeCoverageTargets)
            }
        }()

        return XCTestPlan.Options(
            commandLineArgumentEntries: commandLineArgumentEntries,
            environmentVariableEntries: environmentVariableEntries,
            targetForVariableExpansion: targetForVariableExpansion,
            language: language,
            region: region,
            locationScenario: locationScenario,
            uiTestingScreenshotsLifetime: uiTestingScreenshotsLifetime,
            preferredScreenCaptureFormat: preferredScreenCaptureFormat,
            areLocalizationScreenshotsEnabled: areLocalizationScreenshotsEnabled,
            distributor: distributor,
            userAttachmentLifetime: userAttachmentLifetime,
            diagnosticCollectionPolicy: diagnosticCollectionPolicy,
            testExecutionOrdering: testExecutionOrdering,
            testTimeoutsEnabled: testTimeoutsEnabled,
            defaultTestExecutionTimeAllowance: defaultTestExecutionTimeAllowance,
            maximumTestExecutionTimeAllowance: maximumTestExecutionTimeAllowance,
            testRepetitionMode: testRepetitionMode,
            maximumTestRepetitions: maximumTestRepetitions,
            repeatInNewRunnerProcess: repeatInNewRunnerProcess,
            codeCoverage: codeCoverageMapped,
            addressSanitizer: addressSanitizer,
            threadSanitizerEnabled: threadSanitizerEnabled,
            undefinedBehaviorSanitizerEnabled: undefinedBehaviorSanitizerEnabled,
            mainThreadCheckerDetectionPolicy: mainThreadCheckerDetectionPolicy,
            threadPerformanceCheckerRuntimeIssueDetection: threadPerformanceCheckerRuntimeIssueDetection,
            runtimeIssueDetection: runtimeIssueDetection,
            checkedAllocations: checkedAllocations,
            mallocScribbleEnabled: mallocScribbleEnabled,
            mallocGuardEdgesEnabled: mallocGuardEdgesEnabled,
            nsZombieEnabled: nsZombieEnabled,
            mallocStackLoggingOptions: convertedMallocStackLoggingOptions,
        )
    }
}
