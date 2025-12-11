import Foundation

@testable import ProjectDescription

extension Config {
    public static func manifestTest(
        generationOptions: Config.GenerationOptions = .options(),
        plugins: [PluginLocation] = []
    ) -> Config {
        Config(plugins: plugins, generationOptions: generationOptions)
    }
}

extension Template {
    public static func manifestTest(
        description: String = "Template",
        attributes: [Attribute] = [],
        items: [Template.Item] = []
    ) -> Template {
        Template(
            description: description,
            attributes: attributes,
            items: items
        )
    }
}

extension Workspace {
    public static func manifestTest(
        name: String = "Workspace",
        projects: [FilePath] = [],
        schemes: [Scheme] = [],
        additionalFiles: [FileElement] = []
    ) -> Workspace {
        Workspace(
            name: name,
            projects: projects,
            schemes: schemes,
            additionalFiles: additionalFiles
        )
    }
}

extension Project {
    public static func manifestTest(
        name: String = "Project",
        organizationName: String? = nil,
        settings: Settings = .default,
        targets: [Target] = [],
        additionalFiles: [FileElement] = []
    ) -> Project {
        Project(
            name: name,
            organizationName: organizationName,
            settings: settings,
            targets: targets,
            additionalFiles: additionalFiles
        )
    }
}

extension Target {
    public static func manifestTest(
        name: String = "Target",
        destinations: Destinations = .iOS,
        product: Product = .framework,
        productName: String? = nil,
        bundleId: String = "com.some.bundle.id",
        infoPlist: InfoPlist = .file(path: "Info.plist"),
        sources: SourceFilesList = "Sources/**",
        resources: ResourceFileElements = "Resources/**",
        headers: HeadersList? = nil,
        entitlements: Entitlements = .file(path: "Entitlements.entitlements"),
        scripts: [TargetScript] = [],
        dependencies: [TargetDependency] = [],
        settings: Settings? = nil,
        coreDataModels: [CoreDataModel] = [],
        environment: [String: String] = [:]
    ) -> Target {
        Target(
            name: name,
            destinations: destinations,
            product: product,
            productName: productName,
            bundleId: bundleId,
            infoPlist: infoPlist,
            sources: sources,
            resources: resources,
            headers: headers,
            entitlements: entitlements,
            scripts: scripts,
            dependencies: dependencies,
            settings: settings,
            coreDataModels: coreDataModels,
            environmentVariables: environment.mapValues { .init(stringLiteral: $0) }
        )
    }
}

extension TargetScript {
    public static func manifestTest(
        name: String = "Action",
        tool: String = "",
        order: Order = .pre,
        arguments: [String] = [],
        inputPaths: FileList = [],
        inputFileListPaths: [FilePath] = [],
        outputPaths: FileList = [],
        outputFileListPaths: [FilePath] = [],
        dependencyFile: FilePath? = nil
    ) -> TargetScript {
        TargetScript(
            name: name,
            order: order,
            script: .tool(path: tool, args: arguments),
            inputPaths: inputPaths,
            inputFileListPaths: inputFileListPaths,
            outputPaths: outputPaths,
            outputFileListPaths: outputFileListPaths,
            dependencyFile: dependencyFile
        )
    }
}

extension Scheme {
    public static func manifestTest(
        name: String = "Scheme",
        shared: Bool = false,
        buildAction: BuildAction? = nil,
        testAction: TestAction? = nil,
        runAction: RunAction? = nil
    ) -> Scheme {
        Scheme(
            name: name,
            shared: shared,
            buildAction: buildAction,
            testAction: testAction,
            runAction: runAction
        )
    }
}

extension BuildAction {
    public static func manifestTest(targets: [TargetReference] = []) -> BuildAction {
        BuildAction(
            targets: targets,
            preActions: [ExecutionAction.manifestTest()],
            postActions: [ExecutionAction.manifestTest()]
        )
    }
}

extension TestAction {
    public static func manifestTest(
        targets: [TestableTarget] = [],
        arguments: Arguments? = nil,
        configuration: ConfigurationName = .debug,
        coverage: Bool = true
    ) -> TestAction {
        TestAction.targets(
            targets,
            arguments: arguments,
            configuration: configuration,
            preActions: [ExecutionAction.manifestTest()],
            postActions: [ExecutionAction.manifestTest()],
            options: .options(coverage: coverage)
        )
    }
}

extension RunAction {
    public static func manifestTest(
        configuration: ConfigurationName = .debug,
        executable: TargetReference? = nil,
        arguments: Arguments? = nil
    ) -> RunAction {
        RunAction(
            configuration: configuration,
            executable: executable,
            arguments: arguments
        )
    }
}

extension ExecutionAction {
    public static func manifestTest(
        title: String = "Test Script",
        scriptText: String = "echo Test",
        target: TargetReference? = TargetReference(projectPath: nil, target: "Target")
    ) -> ExecutionAction {
        ExecutionAction(
            title: title,
            scriptText: scriptText,
            target: target
        )
    }
}

extension Arguments {
    public static func manifestTest(
        environment: [String: String] = [:],
        launchArguments: [LaunchArgument] = []
    ) -> Arguments {
        Arguments(
            environmentVariables: environment.mapValues { .init(stringLiteral: $0) },
            launchArguments: launchArguments
        )
    }
}

extension Dependencies {
    public static func manifestTest() -> Dependencies {
        Dependencies()
    }
}

extension Plugin {
    public static func manifestTest(name: String = "Plugin") -> Plugin {
        Plugin(name: name)
    }
}

extension PackageSettings {
    public static func manifestTest() -> PackageSettings {
        PackageSettings()
    }
}
