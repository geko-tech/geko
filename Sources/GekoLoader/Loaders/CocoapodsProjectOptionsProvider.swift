import Foundation
import GekoGraph
import struct ProjectDescription.AbsolutePath

final class CocoapodsProjectOptionsProvider {

    private let workspaceGenerationOptions: Workspace.GenerationOptions
    private let testPlansByTarget: [String: [AbsolutePath]]

    init(workspaceGenerationOptions: Workspace.GenerationOptions, testPlansByTarget: [String: [AbsolutePath]]) {
        self.workspaceGenerationOptions = workspaceGenerationOptions
        self.testPlansByTarget = testPlansByTarget
    }

    func provide(for targets: [GekoGraph.Target]) -> GekoGraph.Project.Options {
        var automaticSchemesOptions: Project.Options.AutomaticSchemesOptions = .disabled

        if case .enabled = workspaceGenerationOptions.autogenerateLocalPodsSchemes {
            automaticSchemesOptions = .enabled(
                targetSchemesGrouping: .pods,
                codeCoverageEnabled: true,
                testingOptions: [],
                testPlans: targets.compactMap { testPlansByTarget[$0.name] }.flatMap { $0 }.map { $0.pathString }
            )
        }

        return .init(
            automaticSchemesOptions: automaticSchemesOptions,
            disableBundleAccessors: true,
            disableShowEnvironmentVarsInScriptPhases: false,
            textSettings: GekoGraph.Project.Options.TextSettings(
                usesTabs: nil,
                indentWidth: nil,
                tabWidth: nil,
                wrapsLines: nil
            ),
            xcodeProjectName: nil
        )
    }
}
