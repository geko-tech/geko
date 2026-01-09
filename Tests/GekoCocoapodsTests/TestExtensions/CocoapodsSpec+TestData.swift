@testable import GekoCocoapods

extension CocoapodsSpec {
    static func test(
        name: String = "",
        sourceFiles: [String] = [],
        staticFramework: Bool? = false
    ) -> CocoapodsSpec {
        return CocoapodsSpec(
            name: name,
            moduleName: nil,
            version: "1.0.0",
            swiftVersion: nil,
            staticFramework: staticFramework,
            dependencies: [:],
            platforms: nil,
            source: .none,
            vendoredFrameworks: [],
            vendoredLibraries: [],
            sourceFiles: sourceFiles,
            excludeFiles: [],
            publicHeaderFiles: [],
            privateHeaderFiles: [],
            projectHeaderFiles: [],
            headerMappingsDir: nil,
            moduleMap: nil,
            podTargetXCConfig: [:],
            infoPlist: [:],
            compilerFlags: [],
            requiresArc: nil,
            frameworks: [],
            weakFrameworks: [],
            libraries: [],
            resources: [],
            resourceBundles: [:],
            preservePaths: [],
            defaultSubspecs: [],
            subspecs: [],
            testSpecs: [],
            appSpecs: [],
            testType: nil,
            requiresAppHost: nil,
            appHostName: nil,
            scriptPhases: nil,
            platformValues: [:],
            prepareCommand: nil
        )
    }
}
