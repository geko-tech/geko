import Foundation
import ProjectDescription
import GekoCore
import GekoLoaderTesting
import Glob
import GekoGraph
import XCTest

@testable import GekoGraph
@testable import GekoLoader
@testable import GekoCoreTesting
@testable import GekoSupportTesting

final class ResolvePathsTests: GekoUnitTestCase {
    func test_config_resolvePaths_resolvesAllPaths() throws {
        var config = Config.init(
            compatibleXcodeVersions: .list([.exact("1.0.0"), .upToNextMajor("2.0.0")]),
            cloud: .cloud(bucket: "bucket", url: "https://url.com"),
            cache: .init(
                profiles: [
                    .profile(
                        name: "Default",
                        configuration: "Debug",
                        platforms: [.iOS: .arm64]
                    )
                ],
                path: "@/.cache"
            ),
            swiftVersion: "6.0.0",
            plugins: [
                .git(url: "https://url.com", sha: "1234"),
                .local(path: "plugin/path"),
                .remote(baseUrl: "https://url.com/plugin", name: "myplugin", version: "1.0.0"),
            ],
            generationOptions: .options(
                resolveDependenciesWithSystemScm: false,
                addAstPathsToLinker: .disabled
            ),
            preFetchScripts: [
                .script("echo 'pre fecth'")
            ],
            preGenerateScripts: [
                .script("echo 'hello world'")
            ],
            postGenerateScripts: [
                .plugin(name: "myplugin"),
            ],
            cocoapodsUseBundler: true
        )

        let rootDirectoryLocator = MockRootDirectoryLocator()
        rootDirectoryLocator.locateStub = "/"

        let generatorPaths = GeneratorPaths(
            manifestDirectory: "/",
            rootDirectoryLocator: rootDirectoryLocator
        )

        // when
        try config.resolvePaths(generatorPaths: generatorPaths)

        var pathStack: [String] = ["Config"]
        try validateAllPathsAreAbsolute(for: config, pathStack: &pathStack)
    }

    func test_project_resolvePaths_resolvesAllPaths() throws {
        let dependencies: [TargetDependency] = [
            TargetDependency.bundle(path: "@/bundle"),
            TargetDependency.external(name: "Alamofire"),
            TargetDependency.framework(path: "@/framework.framework", status: .required),
            TargetDependency.library(
                path: "@/path/to/library.a",
                publicHeaders: "@/path/to/headers",
                swiftModuleMap: "@/path/to/modulemap"
            ),
            TargetDependency.local(name: "local", status: .required),
            TargetDependency.project(target: "target", path: "@/project", status: .required),
            TargetDependency.sdk(name: "Foundation", type: .framework, status: .required),
            TargetDependency.target(name: "target", status: .required),
            TargetDependency.xcframework(path: "@/framework.xcframework", status: .required),
            TargetDependency.xctest
        ]

        let headers: HeadersList = HeadersList.headers([
            Headers(
                public: ["@/headers/**/*.h"],
                private: ["@/headers/private/**/*.h"],
                project: ["@/headers/project/**/*.h"],
                mappingsDir: "@/headers",
                exclusionRule: .publicExcludesPrivateAndProject,
                compilationCondition: .when([.ios])
            )
        ])

        let resources: ResourceFileElements = [
            ResourceFileElement.glob(
                pattern: "@/resources/**/*.png",
                excluding: ["@/resources/**/*excluded.png"],
                tags: ["tag"]
            )
        ]

        let targets: [ProjectDescription.Target] = [
            Target(
                name: "target",
                destinations: Destinations.iOS,
                product: Product.app,
                productName: "myapp",
                bundleId: "com.example.myapp",
                deploymentTargets: DeploymentTargets.iOS("13.0"),
                infoPlist: InfoPlist.file(path: "@/file.plist"),
                buildableFolders: [
                    BuildableFolder("@/buildable-folder", exceptions: ["@/buildable-folder/**/*.yml"])
                ],
                sources: [
                    SourceFiles(
                        paths: ["@/sources/**/*.swift"],
                        excluding: ["@/sources/**/*excluded.swift"]
                    ),
                    "sources2/**/*.swift"
                ],
                playgrounds: ["@/playground.playground"],
                resources: resources,
                copyFiles: [
                    CopyFilesAction(
                        name: "Copy Files",
                        destination: .resources,
                        subpath: "res",
                        files: ["@/resources/**/*.png"]
                    )
                ],
                headers: headers,
                entitlements: Entitlements.file(path: "@/file.entitlements"),
                scripts: [
                    TargetScript.pre(
                        path: "@/pre-script.sh",
                        arguments: "arg",
                        name: "script",
                        inputPaths: ["@/input-paths/**/*"],
                        inputFileListPaths: ["@/input-file-lists/**/*"],
                        outputPaths: ["@/output-paths/**/*"],
                        outputFileListPaths: ["@/output-file-lists/**/*"],
                        showEnvVarsInLog: true,
                        basedOnDependencyAnalysis: nil,
                        runForInstallBuildsOnly: false,
                        shellPath: "/bin/sh",
                        dependencyFile: "@/dependency-file"
                    ),
                ],
                dependencies: dependencies,
                ignoreDependencies: dependencies,
                prioritizeDependencies: dependencies,
                settings: .settings(
                    base: [:],
                    baseDebug: [:],
                    configurations: [
                        .debug(name: "Debug-Optimized", settings: [:], xcconfig: "@/debug-optimized.xcconfig")
                    ],
                    defaultSettings: .recommended
                ),
                coreDataModels: [
                    CoreDataModel("@/coredata.xcdatamodel", versions: ["@/coredatav1.xcdatamodel"], currentVersion: nil)
                ],
                environmentVariables: [:],
                launchArguments: [.init(name: "arg", isEnabled: true)],
                additionalFiles: ["@/**/*.yml"],
                preCreatedFiles: ["path/to/file.swift"],
                buildRules: [
                    BuildRule(
                        name: nil,
                        fileType: .coreMLMachineLearning,
                        filePatterns: nil,
                        compilerSpec: .coreMLModelCompiler,
                        inputFiles: [],
                        outputFiles: [],
                        outputFilesCompilerFlags: [],
                        script: nil,
                        runOncePerArchitecture: false
                    )
                ],
                mergedBinaryType: .disabled,
                mergeable: false,
                filesGroup: .group(name: "Project")
            )
        ]

        var project: ProjectDescription.Project = ProjectDescription.Project(
            name: "Name",
            organizationName: "Organization name",
            options: .options(
                automaticSchemesOptions: .enabled(
                    targetSchemesGrouping: .byNameSuffix(build: [], test: [], run: []),
                    codeCoverageEnabled: false,
                    testingOptions: .randomExecutionOrdering,
                    testLanguage: "en",
                    testRegion: "region",
                    testScreenCaptureFormat: .screenRecording,
                    runLanguage: "en",
                    runRegion: "region",
                    testPlans: ["testplan"]
                ),
                defaultKnownRegions: nil,
                developmentRegion: nil,
                disableBundleAccessors: true,
                disableShowEnvironmentVarsInScriptPhases: true,
                textSettings: .textSettings(
                    usesTabs: true,
                    indentWidth: 4,
                    tabWidth: 4,
                    wrapsLines: true
                ),
                xcodeProjectName: "Project name"
            ),
            settings: .default,
            targets: targets,
            schemes: [
                .init(
                    name: "SchemeName",
                    shared: true,
                    hidden: false,
                    buildAction: .buildAction(
                        targets: [
                            .project(path: "project", target: "Target"),
                            .project(path: "@/project", target: "Target"),
                            .project(path: "/project", target: "Target"),
                        ],
                        preActions: [
                            .init(
                                title: "Pre Script",
                                scriptText: "echo \"hellope\"",
                                target: .project(path: "project", target: "target"),
                                shellPath: "/bin/sh",
                                showEnvVarsInLog: true
                            )
                        ],
                        postActions: [
                            .init(
                                title: "Post Script",
                                scriptText: "echo \"hellope\"",
                                target: .project(path: "project", target: "target"),
                                shellPath: "/bin/sh",
                                showEnvVarsInLog: true
                            )
                        ],
                        buildImplicitDependencies: true,
                        runPostActionsOnFailure: false
                    ),
                    testAction: .testPlans([
                        "testplan.xctestplan",
                        "@/testplan2.xctestplan",
                        "/testplan3.xctestplan",
                    ]),
                    runAction: .runAction(
                        configuration: .debug,
                        attachDebugger: true,
                        customLLDBInitFile: "@/.lldbinit",
                        preActions: [
                            .init(
                                title: "Pre Script",
                                scriptText: "echo \"hellope\"",
                                target: .project(path: "project", target: "target"),
                                shellPath: "/bin/sh",
                                showEnvVarsInLog: true
                            )
                        ],
                        postActions: [
                            .init(
                                title: "Pre Script",
                                scriptText: "echo \"hellope\"",
                                target: .project(path: "@/project", target: "target"),
                                shellPath: "/bin/sh",
                                showEnvVarsInLog: true
                            )
                        ],
                        executable: .project(path: "@/project", target: "target"),
                        arguments: .init(environmentVariables: ["": ""], launchArguments: [.init(name: "arg", isEnabled: true)]),
                        options: .options(
                            language: .accentedPseudoLanguage,
                            storeKitConfigurationPath: "@/config-path",
                            simulatedLocation: .gpxFile("@/file.gpx"),
                            enableGPUFrameCaptureMode: .metal
                        ),
                        diagnosticsOptions: .options(
                            addressSanitizerEnabled: false,
                            detectStackUseAfterReturnEnabled: false,
                            threadSanitizerEnabled: false,
                            undefinedBehaviorSanitizerEnabled: false,
                            ubSanitizerEnabled: false,
                            mainThreadCheckerEnabled: true,
                            performanceAntipatternCheckerEnabled: true,
                            gpuValidationModeEnabled: true
                        ),
                        expandVariableFromTarget: .project(path: "@/project", target: "target"),
                        launchStyle: .automatically
                    ),
                    archiveAction: .archiveAction(
                        configuration: "config",
                        revealArchiveInOrganizer: true,
                        customArchiveName: "MyArchive",
                        preActions: [
                            .init(
                                title: "Pre Script",
                                scriptText: "echo \"hellope\"",
                                target: .project(path: "project", target: "target"),
                                shellPath: "/bin/sh",
                                showEnvVarsInLog: true
                            )
                        ],
                        postActions: [
                            .init(
                                title: "Pre Script",
                                scriptText: "echo \"hellope\"",
                                target: .project(path: "@/project", target: "target"),
                                shellPath: "/bin/sh",
                                showEnvVarsInLog: true
                            )
                        ]
                    ),
                    profileAction: .profileAction(
                        configuration: .release,
                        preActions: [
                            .init(
                                title: "Pre Script",
                                scriptText: "echo \"hellope\"",
                                target: .project(path: "@/project", target: "target"),
                                shellPath: "/bin/sh",
                                showEnvVarsInLog: true
                            )
                        ],
                        postActions: [
                            .init(
                                title: "Post Script",
                                scriptText: "echo \"hellope\"",
                                target: .project(path: "@/project", target: "target"),
                                shellPath: "/bin/sh",
                                showEnvVarsInLog: true
                            )
                        ],
                        executable: .project(path: "@/project", target: "target"),
                        arguments: .init(environmentVariables: ["var": "true"], launchArguments: [.init(name: "arg", isEnabled: true)])
                    ),
                    analyzeAction: .analyzeAction(configuration: "Config")
                )
            ],
            fileHeaderTemplate: .file("@/header-template.txt"),
            additionalFiles: [
                .file(path: "file.yml"),
                .folderReference(path: "folder"),
                .glob(pattern: "**/*.yml"),
                .file(path: "@/file.yml"),
                .folderReference(path: "@/folder"),
                .glob(pattern: "@/**/*.yml"),
                .file(path: "/file.yml"),
                .folderReference(path: "/folder"),
                .glob(pattern: "/**/*.yml"),
            ]
        )

        let rootDirectoryLocator = MockRootDirectoryLocator()
        rootDirectoryLocator.locateStub = "/"

        fileHandler.stubGlob = { _, _ in [] }

        let generatorPaths = GeneratorPaths(manifestDirectory: "/", rootDirectoryLocator: rootDirectoryLocator)
        try project.resolvePaths(generatorPaths: generatorPaths)

        var pathStack: [String] = ["Project"]
        try validateAllPathsAreAbsolute(for: project, pathStack: &pathStack)

        try project.resolveGlobs(checkFilesExist: false)

        pathStack = ["Project"]
        try validateAllGlobsAreResolved(for: project, pathStack: &pathStack)
    }

    private func validateAllPathsAreAbsolute(for subject: Any, pathStack: inout [String]) throws {
        let mirror = Mirror(reflecting: subject)

        if let path = subject as? FilePath {
            if !path.isAbsolute {
                XCTFail("path '\(path) at \(pathStack.joined(separator: ".")) must be resolved to absolute path")
            }
            return
        }

        for (i, child) in mirror.children.enumerated() {
            pathStack.append(child.label ?? "[\(i)]")
            try validateAllPathsAreAbsolute(for: child.value, pathStack: &pathStack)
            pathStack.removeLast()
        }
    }

    private func validateAllGlobsAreResolved(for subject: Any, pathStack: inout [String]) throws {
        let mirror = Mirror(reflecting: subject)

        if let path = subject as? FilePath {
            if !path.isAbsolute || Glob.isGlob(path.pathString) {
                XCTFail("glob '\(path) at \(pathStack.joined(separator: ".")) must be resolved")
            }
            return
        }

        for (i, child) in mirror.children.enumerated() {
            pathStack.append(child.label ?? "[\(i)]")
            try validateAllGlobsAreResolved(for: child.value, pathStack: &pathStack)
            pathStack.removeLast()
        }
    }
}
