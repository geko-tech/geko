import Foundation
import ProjectDescription
import GekoSupport
import GekoCore
import GekoGraph
import GekoLoader
import Crypto

enum XCTestPlanDescriptorGeneratorError: FatalError {
    case targetReferenceNotFound(target: String)
    case specificTestableTargetNotFound(testPlan: String, target: String)
    case generatedProjectNotFound(targetName: String, path: String)

    var type: ErrorType {
        switch self {
        case .targetReferenceNotFound, .specificTestableTargetNotFound, .generatedProjectNotFound:
            return .abort
        }
    }

    var description: String {
        switch self {
        case let .targetReferenceNotFound(target):
            return "Target '\(target)' specified as a test plan reference (variable expansion or code coverage) was not found. Verify that the target exists and is spelled correctly, or change the missing target policy to '.excludeTarget' or '.skipTestPlan'."
        case let .specificTestableTargetNotFound(testPlan, target):
            return "Test plan '\(testPlan)'. Target '\(target)' specified for testing was not found. Verify that the target exists and is spelled correctly, or change the missing target policy to '.excludeTarget' or '.skipTestPlan'."
        case let .generatedProjectNotFound(targetName, path):
            return "Could not find the generated project for target '\(targetName)' at path '\(path)'. This is likely an internal error. Please report this issue."
        }
    }
}

protocol XCTestPlanDescriptorGenerating: AnyObject {
    func xcTestPlanDescriptorsAndGenerateMetadata(
        graphTraverser: GraphTraversing,
        generatedProjects: [AbsolutePath: GeneratedProject],
        sideTable: GraphSideTable
    ) throws -> ([XCTestPlanDescriptor], GenerateMetadata)
}

/// Internal control-flow signal: a referenced target is missing and the policy is `.skipTestPlan`,
/// so the whole test plan should be skipped.
private enum TestPlanSkip: Error {
    case skip
}

private final class GeneratedTestPlanDescriptorContext {
    let allTargets: Set<GraphTarget>
    let rootPath: AbsolutePath
    let generatedProjects: [AbsolutePath: GeneratedProject]

    init(allTargets: Set<GraphTarget>, rootPath: AbsolutePath, generatedProjects: [AbsolutePath : GeneratedProject]) {
        self.allTargets = allTargets
        self.rootPath = rootPath
        self.generatedProjects = generatedProjects
    }
}

final class XCTestPlanDescriptorGenerator: XCTestPlanDescriptorGenerating {

    // MARK: - XCTestPlanDescriptorGenerating

    func xcTestPlanDescriptorsAndGenerateMetadata(
        graphTraverser: GraphTraversing,
        generatedProjects: [AbsolutePath: GeneratedProject],
        sideTable: GraphSideTable
    ) throws -> ([XCTestPlanDescriptor], GenerateMetadata) {

        let allTargets = graphTraverser.allInternalTargets()
        let rootPath = graphTraverser.workspace.xcWorkspacePath.parentDirectory
        let context = GeneratedTestPlanDescriptorContext(allTargets: allTargets, rootPath: rootPath, generatedProjects: generatedProjects)

        let testPlanDescriptors = try graphTraverser.projects.flatMap { (path, project) in
            var generatedTestPlans: [GeneratedTestPlan] = []

            for schemes in project.schemes {
                guard let testPlans = schemes.testAction?.testPlans else { continue }
                let generatedTestPlansFromScheme: [GeneratedTestPlan] = testPlans.compactMap {
                    switch $0 {
                    case .file: nil
                    case let .generated(testPlan): testPlan
                    }
                }
                generatedTestPlans.append(contentsOf: generatedTestPlansFromScheme)
            }

            return try mapXCTestPlanDescriptors(
                generatedTestPlans: generatedTestPlans,
                context: context
            )
        }

        let allTestTargets = try mapAllTargetsToTestTargets(context: context)

        let generateMetadata = GenerateMetadata(
            workspaceName: graphTraverser.workspace.name,
            cacheEnabled: sideTable.workspace.cacheEnabled,
            focusedTargets: sideTable.workspace.focusedTargets,
            allTestTargets: allTestTargets
        )

        return (testPlanDescriptors, generateMetadata)
    }

    // MARK: - Test plan descriptors

    private func mapXCTestPlanDescriptors(
        generatedTestPlans: [GeneratedTestPlan],
        context: GeneratedTestPlanDescriptorContext
    ) throws -> [XCTestPlanDescriptor] {
        try generatedTestPlans.map { generatedTestPlan in
            try descriptor(
                for: generatedTestPlan,
                context: context
            )
        }
    }

    /// Builds the descriptor for a single test plan, or `nil` when the plan should be skipped
    /// (e.g. a requested target is missing and the policy is `.skipTestPlan`).
    private func descriptor(
        for testPlan: GeneratedTestPlan,
        context: GeneratedTestPlanDescriptorContext
    ) throws -> XCTestPlanDescriptor {
        do {
            let configurations: [XCTestPlan.Configuration] = try testPlan.configurations.map { configuration in
                XCTestPlan.Configuration(
                    id: configurationID(path: testPlan.path, name: configuration.name),
                    name: configuration.name,
                    options: try resolveOptions(
                        configuration.options,
                        testPlan: testPlan,
                        context: context
                    )
                )
            }

            let defaultOptions = try resolveOptions(
                testPlan.defaultOptions,
                testPlan: testPlan,
                context: context
            )

            guard let testGraphTargets = try resolveTestTargets(testPlan: testPlan, context: context) else {
                return XCTestPlanDescriptor(
                    path: testPlan.path,
                    plan: nil
                )
            }
            let testTargets = try mapTargetsToTestTargets(targets: testGraphTargets, context: context)

            let plan = XCTestPlan(
                testTargets: testTargets,
                configurations: configurations,
                defaultOptions: defaultOptions ?? .empty,
                version: 1
            )

            return XCTestPlanDescriptor(
                path: testPlan.path,
                plan: plan
            )
        } catch TestPlanSkip.skip {
            return XCTestPlanDescriptor(
                path: testPlan.path,
                plan: nil
            )
        }
    }

    /// Resolves a `GeneratedTestPlan.Options` into the corresponding plan options, expanding its target references.
    ///
    /// Returns `nil` when no options are configured. Throws `TestPlanSkip` when a referenced target is missing
    /// and the policy is `.skipTestPlan`, meaning the whole test plan should be skipped.
    private func resolveOptions(
        _ options: GeneratedTestPlan.Options?,
        testPlan: GeneratedTestPlan,
        context: GeneratedTestPlanDescriptorContext
    ) throws -> XCTestPlan.Options? {
        guard let options else { return nil }

        let targetForVariableExpansion = try resolveTestTargetReference(
            target: options.targetForVariableExpansion?.name,
            testPlan: testPlan,
            context: context
        )

        let codeCoverageTargets = try resolveCodeCoverageTargets(
            codeCoverage: options.codeCoverage,
            testPlan: testPlan,
            context: context
        )

        return options.map(
            targetForVariableExpansion: targetForVariableExpansion,
            codeCoverageTargets: codeCoverageTargets
        )
    }

    /// Resolves the code-coverage target references for an options set.
    ///
    /// Throws `TestPlanSkip` when a requested coverage target is missing and the policy is `.skipTestPlan`.
    private func resolveCodeCoverageTargets(
        codeCoverage: GeneratedTestPlan.Options.Coverage?,
        testPlan: GeneratedTestPlan,
        context: GeneratedTestPlanDescriptorContext
    ) throws -> [XCTestPlan.TestTargetReference] {
        guard case let .selected(targets) = codeCoverage else { return [] }

        return try targets.compactMap { target in
            try resolveTestTargetReference(
                target: target.name,
                testPlan: testPlan,
                context: context
            )
        }
    }

    /// Resolves the explicitly listed targets, honoring the missing-target policy.
    ///
    /// Returns `nil` when the whole test plan should be skipped (`.skipTestPlan` policy).
    private func resolveTestTargets(
        testPlan: GeneratedTestPlan,
        context: GeneratedTestPlanDescriptorContext
    ) throws -> [(GeneratedTestPlanTestableTarget, GraphTarget)]? {
        var graphTargets: [(GeneratedTestPlanTestableTarget, GraphTarget)] = []

        for testTarget in testPlan.testTargets {
            guard let graphTarget = context.allTargets.first(where: { $0.target.name == testTarget.target.target.targetName }) else {
                switch testPlan.missingTargetPolicy {
                case let .skipTestPlan(notification):
                    warnIfNeeded(
                        notification,
                        testPlan: testPlan.name,
                        target: testTarget.target.target.name,
                        action: "The test plan will be skipped."
                    )
                    return nil
                case let .skipTarget(notification):
                    warnIfNeeded(
                        notification,
                        testPlan: testPlan.name,
                        target: testTarget.target.target.name,
                        action: "The target will be excluded from the test plan."
                    )
                    continue
                case .fail:
                    throw XCTestPlanDescriptorGeneratorError.specificTestableTargetNotFound(
                        testPlan: testPlan.name,
                        target: testTarget.target.target.name
                    )
                }
            }

            graphTargets.append((testTarget, graphTarget))
        }

        return graphTargets
    }

    private func warnIfNeeded(
        _ notification: GeneratedTestPlan.MissingTargetPolicy.Notification,
        testPlan: String,
        target: String,
        action: String,
    ) {
        guard case .warning = notification else { return }
        logger.warning(
            "Test plan '\(testPlan)'. Target '\(target)' specified for testing was not found. Verify that the target exists and is spelled correctly. \(action)"
        )
    }

    /// Resolves an optional target reference, honoring the missing-target policy.
    ///
    /// Returns `nil` when no target is configured or a missing one was excluded (`.skipTarget` policy).
    /// Throws `TestPlanSkip` when the whole test plan should be skipped (`.skipTestPlan` policy).
    private func resolveTestTargetReference(
        target: String?,
        testPlan: GeneratedTestPlan,
        context: GeneratedTestPlanDescriptorContext
    ) throws -> XCTestPlan.TestTargetReference? {
        guard let target else { return nil }

        guard let graphTarget = context.allTargets.first(where: { $0.target.name == target }) else {
            switch testPlan.missingTargetPolicy {
            case let .skipTestPlan(notification):
                warnIfNeeded(
                    notification,
                    testPlan: testPlan.name,
                    target: target,
                    action: "The test plan will be skipped."
                )
                throw TestPlanSkip.skip
            case let .skipTarget(notification):
                warnIfNeeded(
                    notification,
                    testPlan: testPlan.name,
                    target: target,
                    action: "The target will be ignored."
                )
                return nil
            case .fail:
                throw XCTestPlanDescriptorGeneratorError.targetReferenceNotFound(target: target)
            }
        }

        return try testTargetReference(
            graphTarget: graphTarget,
            context: context
        )
    }

    // MARK: - Test targets

    private func mapAllTargetsToTestTargets(context: GeneratedTestPlanDescriptorContext) throws -> [XCTestPlan.TestTarget] {
        let targets = context.allTargets
            .filter(\.target.product.testsBundle)
            .map { graphTarget in
                (GeneratedTestPlanTestableTarget(stringLiteral: graphTarget.target.name), graphTarget)
            }
        return try mapTargetsToTestTargets(targets: targets, context: context)
    }

    private func mapTargetsToTestTargets(
        targets: [(testableTarget: GeneratedTestPlanTestableTarget, graphTarget: GraphTarget)],
        context: GeneratedTestPlanDescriptorContext
    ) throws -> [XCTestPlan.TestTarget] {
        let testTargets = try targets.map { target in
            try testTarget(target: target, context: context)
        }
        return testTargets.sorted(by: { $0.target.name < $1.target.name })
    }

    private func testTarget(
        target: (testableTarget: GeneratedTestPlanTestableTarget, graphTarget: GraphTarget),
        context: GeneratedTestPlanDescriptorContext
    ) throws -> XCTestPlan.TestTarget {

        let (testableTarget, graphTarget) = target

        return XCTestPlan.TestTarget(
            target: try testTargetReference(graphTarget: graphTarget, context: context),
            selectedTests: testableTarget.selectedTests.isEmpty ? nil : testableTarget.selectedTests,
            skippedTests: testableTarget.skippedTests.isEmpty ? nil : testableTarget.skippedTests,
            enabled: testableTarget.target.isSkipped ? false : nil,
            parallelizable: testableTarget.target.isParallelizable ? true : nil
        )
    }

    private func testTargetReference(
        graphTarget: GraphTarget,
        context: GeneratedTestPlanDescriptorContext
    ) throws -> XCTestPlan.TestTargetReference {
        let xcodeProjectPath = graphTarget.project.xcodeProjPath

        guard
            let generatedProject = context.generatedProjects[xcodeProjectPath],
            let pbxTarget = generatedProject.targets[graphTarget.target.name]
        else {
            throw XCTestPlanDescriptorGeneratorError.generatedProjectNotFound(
                targetName: graphTarget.target.name,
                path: xcodeProjectPath.pathString
            )
        }

        let containerRelativePath = xcodeProjectPath.relative(to: context.rootPath).pathString

        return XCTestPlan.TestTargetReference(
            containerPath: "container:\(containerRelativePath)",
            identifier: pbxTarget.uuid,
            name: pbxTarget.name,
        )
    }

    private func configurationID(path: AbsolutePath, name: String) -> UUID {
        let digest = Array(SHA256.hash(data: Data((path.pathString + name).utf8)).prefix(16))
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        ))
    }
}
