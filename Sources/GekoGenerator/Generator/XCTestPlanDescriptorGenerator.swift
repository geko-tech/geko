import Foundation
import ProjectDescription
import GekoSupport
import GekoCore
import GekoGraph
import GekoLoader

enum XCTestPlanDescriptorGeneratorError: FatalError {
    case targetForVariableExpansionNotFound(target: String)
    case specificTestableTargetNotFound(testPlan: String, target: String)
    case generatedProjectNotFound(targetName: String, path: String)

    var type: ErrorType {
        switch self {
        case .targetForVariableExpansionNotFound, .specificTestableTargetNotFound, .generatedProjectNotFound:
            return .abort
        }
    }

    var description: String {
        switch self {
        case let .targetForVariableExpansionNotFound(target):
            return "Target '\(target)' specified for variable expansion not found."
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

/// Outcome of resolving a variable-expansion target for a test plan.
private enum VariableExpansionTargetResolution {
    /// No variable-expansion target was configured, or a missing one was excluded.
    case none
    /// The variable-expansion target was resolved.
    case resolved(XCTestPlanDescriptor.TestTarget)
    /// A requested target is missing and the policy is `.skipTestPlan`.
    case skipTestPlan
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
                generatedProjects: generatedProjects,
                allTargets: allTargets,
                rootPath: path
            )
        }

        let allTestTargets = try mapAllTargetsToTestTargets(
            allTargets: allTargets,
            rootPath: rootPath,
            generatedProjects: generatedProjects
        ).mapTestTargets()

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
        generatedProjects: [AbsolutePath: GeneratedProject],
        allTargets: Set<GraphTarget>,
        rootPath: AbsolutePath,
    ) throws -> [XCTestPlanDescriptor] {
        try generatedTestPlans.compactMap { generatedTestPlan in
            try descriptor(
                for: generatedTestPlan,
                generatedProjects: generatedProjects,
                allTargets: allTargets,
                rootPath: rootPath
            )
        }
    }

    /// Builds the descriptor for a single test plan, or `nil` when the plan should be skipped
    /// (e.g. a requested target is missing and the policy is `.skipTestPlan`).
    private func descriptor(
        for generatedTestPlan: GeneratedTestPlan,
        generatedProjects: [AbsolutePath: GeneratedProject],
        allTargets: Set<GraphTarget>,
        rootPath: AbsolutePath,
    ) throws -> XCTestPlanDescriptor? {
        var descriptiorConfigurations: [XCTestPlanDescriptor.Configuration] = []
        for configuration in generatedTestPlan.configurations {
            let configurationOptionsTargetForVariableExpansion: XCTestPlanDescriptor.TestTarget?
            switch try descriptorTestTargetForVariableExpansion(
                target: configuration.options?.targetForVariableExpansion,
                missingTargetPolicy: generatedTestPlan.missingTargetPolicy,
                testPlan: generatedTestPlan.name,
                allTargets: allTargets,
                rootPath: rootPath,
                generatedProjects: generatedProjects
            ) {
            case .none:
                configurationOptionsTargetForVariableExpansion = nil
            case let .resolved(testTarget):
                configurationOptionsTargetForVariableExpansion = testTarget
            case .skipTestPlan:
                return nil
            }

            descriptiorConfigurations.append(
                XCTestPlanDescriptor.Configuration(configuration: configuration, targetForVariableExpansion: configurationOptionsTargetForVariableExpansion)
            )
        }

        let defaultOptionsTargetForVariableExpansion: XCTestPlanDescriptor.TestTarget?
        switch try descriptorTestTargetForVariableExpansion(
            target: generatedTestPlan.defaultOptions?.targetForVariableExpansion,
            missingTargetPolicy: generatedTestPlan.missingTargetPolicy,
            testPlan: generatedTestPlan.name,
            allTargets: allTargets,
            rootPath: rootPath,
            generatedProjects: generatedProjects
        ) {
        case .none:
            defaultOptionsTargetForVariableExpansion = nil
        case let .resolved(testTarget):
            defaultOptionsTargetForVariableExpansion = testTarget
        case .skipTestPlan:
            return nil
        }

        guard let testGraphTargets = try resolveTestTargets(
            generatedTestPlan.testTargets,
            missingTargetPolicy: generatedTestPlan.missingTargetPolicy,
            testPlan: generatedTestPlan.name,
            allTargets: allTargets
        ) else {
            return nil
        }
        let testTargets = try mapTargetsToTestTargets(targets: testGraphTargets, rootPath: rootPath, generatedProjects: generatedProjects)

        return XCTestPlanDescriptor(
            path: generatedTestPlan.path,
            configurations: descriptiorConfigurations,
            defaultOptions: generatedTestPlan.defaultOptions,
            defaultOptionsTargetForVariableExpansion: defaultOptionsTargetForVariableExpansion,
            testTargets: testTargets
        )
    }

    /// Resolves the explicitly listed targets, honoring the missing-target policy.
    ///
    /// Returns `nil` when the whole test plan should be skipped (`.skipTestPlan` policy).
    private func resolveTestTargets(
        _ testTargets: [GeneratedTestPlanTestableTarget],
        missingTargetPolicy: GeneratedTestPlan.MissingTargetPolicy,
        testPlan: String,
        allTargets: Set<GraphTarget>,
    ) throws -> [(GeneratedTestPlanTestableTarget, GraphTarget)]? {
        var graphTargets: [(GeneratedTestPlanTestableTarget, GraphTarget)] = []

        for testTarget in testTargets {
            guard let graphTarget = allTargets.first(where: { $0.target.name == testTarget.target.target.targetName }) else {
                switch missingTargetPolicy {
                case let .skipTestPlan(notification):
                    warnIfNeeded(
                        notification,
                        testPlan: testPlan,
                        target: testTarget.target.target.name,
                        action: "The test plan will be skipped."
                    )
                    return nil
                case let .skipTarget(notification):
                    warnIfNeeded(
                        notification,
                        testPlan: testPlan,
                        target: testTarget.target.target.name,
                        action: "The target will be excluded from the test plan."
                    )
                    continue
                case .fail:
                    throw XCTestPlanDescriptorGeneratorError.specificTestableTargetNotFound(
                        testPlan: testPlan,
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

    private func descriptorTestTargetForVariableExpansion(
        target: String?,
        missingTargetPolicy: GeneratedTestPlan.MissingTargetPolicy,
        testPlan: String,
        allTargets: Set<GraphTarget>,
        rootPath: AbsolutePath,
        generatedProjects: [AbsolutePath: GeneratedProject],
    ) throws -> VariableExpansionTargetResolution {
        guard let target else { return .none }

        guard let graphTarget = allTargets.first(where: { $0.target.name == target }) else {
            switch missingTargetPolicy {
            case let .skipTestPlan(notification):
                warnIfNeeded(
                    notification,
                    testPlan: testPlan,
                    target: target,
                    action: "The test plan will be skipped."
                )
                return .skipTestPlan
            case let .skipTarget(notification):
                warnIfNeeded(
                    notification,
                    testPlan: testPlan,
                    target: target,
                    action: "The variable expansion target will be ignored."
                )
                return .none
            case .fail:
                throw XCTestPlanDescriptorGeneratorError.targetForVariableExpansionNotFound(target: target)
            }
        }

        let testTarget = try descriptorTestTarget(
            rootPath: rootPath,
            generatedProjects: generatedProjects,
            target: (GeneratedTestPlanTestableTarget(TestableTarget(stringLiteral: target)), graphTarget)
        )
        return .resolved(testTarget)
    }

    // MARK: - Test targets

    private func mapAllTargetsToTestTargets(
        allTargets: Set<GraphTarget>,
        rootPath: AbsolutePath,
        generatedProjects: [AbsolutePath: GeneratedProject],
    ) throws -> [XCTestPlanDescriptor.TestTarget] {
        let targets = allTargets.filter(\.target.product.testsBundle).map { graphTarget in
            (GeneratedTestPlanTestableTarget(TestableTarget(target: TargetReference(stringLiteral: graphTarget.target.name))), graphTarget)
        }
        return try mapTargetsToTestTargets(targets: targets, rootPath: rootPath, generatedProjects: generatedProjects)
    }

    private func mapTargetsToTestTargets(
        targets: [(testableTarget: GeneratedTestPlanTestableTarget, graphTarget: GraphTarget)],
        rootPath: AbsolutePath,
        generatedProjects: [AbsolutePath: GeneratedProject],
    ) throws -> [XCTestPlanDescriptor.TestTarget] {
        let descriptoTargets = try targets.map { target in
            try descriptorTestTarget(rootPath: rootPath, generatedProjects: generatedProjects, target: target)
        }
        return descriptoTargets.sorted(by: { $0.pbxTarget.name < $1.pbxTarget.name })
    }

    private func descriptorTestTarget(
        rootPath: AbsolutePath,
        generatedProjects: [AbsolutePath: GeneratedProject],
        target: (testableTarget: GeneratedTestPlanTestableTarget, graphTarget: GraphTarget)
    ) throws -> XCTestPlanDescriptor.TestTarget {

        let (testableTarget, graphTarget) = target
        let xcodeProjectPath = graphTarget.project.xcodeProjPath

        guard
            let generatedProject = generatedProjects[xcodeProjectPath],
            let pbxTarget = generatedProject.targets[graphTarget.target.name]
        else {
            throw XCTestPlanDescriptorGeneratorError.generatedProjectNotFound(
                targetName: graphTarget.target.name,
                path: xcodeProjectPath.pathString
            )
        }

        let containerRelativePath = xcodeProjectPath.relative(to: rootPath).pathString

        return XCTestPlanDescriptor.TestTarget(
            pbxTarget: pbxTarget,
            containerPath: "container:\(containerRelativePath)",
            isEnabled: !testableTarget.target.isSkipped,
            isParallelizable: testableTarget.target.isParallelizable,
            selectedTests: testableTarget.selectedTests,
            skippedTests: testableTarget.skippedTests
        )
    }
}
