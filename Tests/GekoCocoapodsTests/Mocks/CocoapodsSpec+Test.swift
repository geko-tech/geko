import GekoCocoapods

extension CocoapodsSpec.Source {
    static func test(
        http: String? = nil,
        sha256: String? = nil,
        git: String? = nil,
        tag: String? = nil,
        branch: String?,
        commit: String?,
        submodules: Bool?,
        flatten: Bool? = nil
    ) -> CocoapodsSpec.Source {
        return CocoapodsSpec.Source(
            http: http,
            sha256: sha256,
            git: git,
            tag: tag,
            branch: branch,
            commit: commit,
            submodules: submodules,
            flatten: flatten
        )
    }
}

extension CocoapodsSpec.Platforms {
    static func test(
        osx: String? = nil,
        ios: String? = nil,
        tvos: String? = nil,
        visionos: String? = nil,
        watchos: String? = nil
    ) -> CocoapodsSpec.Platforms {
        return CocoapodsSpec.Platforms(
            osx: osx,
            ios: ios,
            tvos: tvos,
            visionos: visionos,
            watchos: watchos
        )
    }
}

extension CocoapodsSpec.ScriptPhase {
    static func test(
        name: String,
        shellPath: String? = nil,
        inputFiles: [String]? = nil,
        inputFileLists: [String]? = nil,
        outputFiles: [String]? = nil,
        outputFileLists: [String]? = nil,
        script: String,
        showEnvVarsInLog: Bool? = nil,
        executionPosition: ExecutionPosition? = nil,
        dependencyFile: String? = nil,
        alwaysOutOfDate: Bool? = nil
    ) -> CocoapodsSpec.ScriptPhase {
        return CocoapodsSpec.ScriptPhase(
            name: name,
            shellPath: shellPath,
            inputFiles: inputFiles,
            inputFileLists: inputFileLists,
            outputFiles: outputFiles,
            outputFileLists: outputFileLists,
            script: script,
            showEnvVarsInLog: showEnvVarsInLog,
            executionPosition: executionPosition,
            dependencyFile: dependencyFile,
            alwaysOutOfDate: alwaysOutOfDate
        )
    }
}

extension CocoapodsSpec {
    static func test(
        name: String,
        version: String = "",
        swiftVersion: String? = nil,
        moduleName: String? = nil,
        staticFramework: Bool? = nil,
        dependencies: [String: [String]]? = nil,
        platforms: Platforms? = nil,
        source: Source = .none,
        vendoredFrameworks: [String] = [],
        vendoredLibraries: [String] = [],
        sourceFiles: [String] = [],
        excludeFiles: [String] = [],
        publicHeaderFiles: [String] = [],
        privateHeaderFiles: [String] = [],
        projectHeaderFiles: [String] = [],
        headerMappingsDir: String? = nil,
        moduleMap: ModuleMap? = nil,
        podTargetXCConfig: [String: SettingValue] = [:],
        infoPlist: [String: PlistValue] = [:],
        compilerFlags: [String] = [],
        requiresArc: RequiresArc? = nil,
        frameworks: [String] = [],
        weakFrameworks: [String] = [],
        libraries: [String] = [],
        resources: [String] = [],
        resourceBundles: [String: [String]] = [:],
        preservePaths: [String] = [],
        defaultSubspecs: [String] = [],
        subspecs: [CocoapodsSpec] = [],
        testSpecs: [CocoapodsSpec] = [],
        appSpecs: [CocoapodsSpec] = [],
        testType: TestType? = nil,
        requiresAppHost: Bool? = nil,
        appHostName: String? = nil,
        scriptPhases: [ScriptPhase]? = nil,
        platformValues: [String: CocoapodsSpec] = [:],
        prepareCommand: String? = nil
    ) -> CocoapodsSpec {
        return CocoapodsSpec(
            name: name,
            moduleName: moduleName,
            version: version,
            swiftVersion: swiftVersion,
            staticFramework: staticFramework,
            dependencies: dependencies,
            platforms: platforms,
            source: source,
            vendoredFrameworks: vendoredFrameworks,
            vendoredLibraries: vendoredLibraries,
            sourceFiles: sourceFiles,
            excludeFiles: excludeFiles,
            publicHeaderFiles: publicHeaderFiles,
            privateHeaderFiles: privateHeaderFiles,
            projectHeaderFiles: projectHeaderFiles,
            headerMappingsDir: headerMappingsDir,
            moduleMap: moduleMap,
            podTargetXCConfig: podTargetXCConfig,
            infoPlist: infoPlist,
            compilerFlags: compilerFlags,
            requiresArc: requiresArc,
            frameworks: frameworks,
            weakFrameworks: weakFrameworks,
            libraries: libraries,
            resources: resources,
            resourceBundles: resourceBundles,
            preservePaths: preservePaths,
            defaultSubspecs: defaultSubspecs,
            subspecs: subspecs,
            testSpecs: testSpecs,
            appSpecs: appSpecs,
            testType: testType,
            requiresAppHost: requiresAppHost,
            appHostName: appHostName,
            scriptPhases: scriptPhases,
            platformValues: platformValues,
            prepareCommand: prepareCommand
        )
    }
}
