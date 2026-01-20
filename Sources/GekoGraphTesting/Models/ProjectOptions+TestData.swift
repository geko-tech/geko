import Foundation
import ProjectDescription
@testable import GekoGraph

extension Project.Options {
    public static func test(
        automaticSchemesOptions: AutomaticSchemesOptions = .enabled(
            targetSchemesGrouping: .byNameSuffix(
                build: ["Implementation", "Interface", "Mocks", "Testing"],
                test: ["Tests", "IntegrationTests", "UITests", "SnapshotTests"],
                run: ["App", "Demo"]
            ),
            codeCoverageEnabled: false,
            testingOptions: []
        ),
        defaultKnownRegions: [String]? = nil,
        developmentRegion: String? = nil,
        disableBundleAccessors: Bool = false,
        disableShowEnvironmentVarsInScriptPhases: Bool = false,
        textSettings: TextSettings = .init(usesTabs: nil, indentWidth: nil, tabWidth: nil, wrapsLines: nil),
        xcodeProjectName: String? = nil
    ) -> Self {
        .init(
            automaticSchemesOptions: automaticSchemesOptions,
            defaultKnownRegions: defaultKnownRegions,
            developmentRegion: developmentRegion,
            disableBundleAccessors: disableBundleAccessors,
            disableShowEnvironmentVarsInScriptPhases: disableShowEnvironmentVarsInScriptPhases,
            textSettings: textSettings,
            xcodeProjectName: xcodeProjectName
        )
    }
}

extension Project.Options.TextSettings {
    public static func test(
        usesTabs: Bool? = true,
        indentWidth: UInt? = 2,
        tabWidth: UInt? = 2,
        wrapsLines: Bool? = true
    ) -> Self {
        .init(
            usesTabs: usesTabs,
            indentWidth: indentWidth,
            tabWidth: tabWidth,
            wrapsLines: wrapsLines
        )
    }
}
