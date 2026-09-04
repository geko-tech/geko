import Foundation
import GekoCore
import GekoSupport
import XcodeProj
import GekoLoader
import GekoGraph
import ProjectDescription

enum WorkspaceDescriptorGeneratorError: FatalError {
    case projectNotFound(path: AbsolutePath)
    var type: ErrorType {
        switch self {
        case .projectNotFound:
            return .abort
        }
    }

    var description: String {
        switch self {
        case let .projectNotFound(path: path):
            return "Project not found at path: \(path)"
        }
    }
}

protocol WorkspaceDescriptorGenerating: AnyObject {
    /// Generates the given workspace.
    ///
    /// - Parameters:
    ///   - graphTraverser: Graph traverser.
    ///   - sideTable: Graph side table.
    /// - Returns: Generated workspace descriptor
    /// - Throws: An error if the generation fails.
    func generate(graphTraverser: GraphTraversing, sideTable: GraphSideTable) throws -> WorkspaceDescriptor
}

final class WorkspaceDescriptorGenerator: WorkspaceDescriptorGenerating {
    struct Config {
        /// The execution context to use when generating
        /// descriptors for each project within the workspace / graph
        var projectGenerationContext: ExecutionContext
        static var `default`: Config {
            Config(projectGenerationContext: .concurrent)
        }
    }

    // MARK: - Attributes

    private let projectDescriptorGenerator: ProjectDescriptorGenerating
    private let workspaceStructureGenerator: WorkspaceStructureGenerating
    private let schemeDescriptorsGenerator: SchemeDescriptorsGenerating
    private let workspaceSettingsGenerator: WorkspaceSettingsDescriptorGenerating
    private let config: Config

    // MARK: - Init

    convenience init(
        enforceExplicitDependencies: Bool,
        defaultSettingsProvider: DefaultSettingsProviding = DefaultSettingsProvider(),
        config: Config = .default
    ) {
        let configGenerator = ConfigGenerator(defaultSettingsProvider: defaultSettingsProvider)
        let targetGenerator = TargetGenerator(configGenerator: configGenerator)
        let projectDescriptorGenerator = ProjectDescriptorGenerator(
            enforceExplicitDependencies: enforceExplicitDependencies,
            targetGenerator: targetGenerator,
            configGenerator: configGenerator
        )
        self.init(
            projectDescriptorGenerator: projectDescriptorGenerator,
            workspaceStructureGenerator: WorkspaceStructureGenerator(),
            schemeDescriptorsGenerator: SchemeDescriptorsGenerator(),
            workspaceSettingsGenerator: WorkspaceSettingsDescriptorGenerator(),
            config: config
        )
    }

    init(
        projectDescriptorGenerator: ProjectDescriptorGenerating,
        workspaceStructureGenerator: WorkspaceStructureGenerating,
        schemeDescriptorsGenerator: SchemeDescriptorsGenerating,
        workspaceSettingsGenerator: WorkspaceSettingsDescriptorGenerating,
        config: Config = .default
    ) {
        self.projectDescriptorGenerator = projectDescriptorGenerator
        self.workspaceStructureGenerator = workspaceStructureGenerator
        self.schemeDescriptorsGenerator = schemeDescriptorsGenerator
        self.workspaceSettingsGenerator = workspaceSettingsGenerator
        self.config = config
    }

    // MARK: - WorkspaceGenerating

    // swiftlint:disable:next function_body_length
    func generate(graphTraverser: GraphTraversing, sideTable: GraphSideTable) throws -> WorkspaceDescriptor {
        let workspaceName = "\(graphTraverser.name).xcworkspace"

        graphTraverser.warmup()

        logger.notice("Generating workspace \(workspaceName)", metadata: .section)

        /// Projects
        var projects = try Array(graphTraverser.projects.values)
            .sorted(by: { $0.path < $1.path })
            .compactMap(context: config.projectGenerationContext) { project -> ProjectDescriptor in
                try projectDescriptorGenerator.generate(project: project, graphTraverser: graphTraverser)
            }
        clearingLogger.info("All projects generated")

        logger.info("\nGenerating cross project links", metadata: .subsection)
        try CrossProjectLinkGenerator().generateLinks(
            projects: &projects,
            graphTraverser: graphTraverser
        )

        let generatedProjects: [AbsolutePath: GeneratedProject] = Dictionary(
            uniqueKeysWithValues: projects.map { project in
                let pbxproj = project.xcodeProj.pbxproj
                let nativeTargets = pbxproj.nativeTargets.map { ($0.name, $0) }
                let aggregateTargets = pbxproj.aggregateTargets.map { ($0.name, $0) }
                let targets: [(String, PBXTarget)] = nativeTargets + aggregateTargets

                return (
                    project.xcodeprojPath,
                    GeneratedProject(
                        pbxproj: pbxproj,
                        path: project.xcodeprojPath,
                        targets: Dictionary(targets, uniquingKeysWith: { $1 }),
                        name: project.xcodeprojPath.basename
                    )
                )
            }
        )

        // Workspace structure
        let structure = workspaceStructureGenerator.generateStructure(
            path: graphTraverser.workspace.xcWorkspacePath.parentDirectory,
            workspace: graphTraverser.workspace,
            xcodeProjPaths: generatedProjects.keys.map { $0 },
            fileHandler: FileHandler.shared
        )

        let workspaceData = XCWorkspaceData(children: [])
        let xcWorkspace = XCWorkspace(data: workspaceData)
        try workspaceData.children = structure.contents.map {
            try recursiveChildElement(
                generatedProjects: generatedProjects,
                element: $0,
                path: graphTraverser.workspace.xcWorkspacePath.parentDirectory
            )
        }

        // Schemes
        let schemes = try schemeDescriptorsGenerator.generateWorkspaceSchemes(
            workspace: graphTraverser.workspace,
            generatedProjects: generatedProjects,
            graphTraverser: graphTraverser
        )

        try projects.forEach(context: config.projectGenerationContext) {
            try ReferenceGenerator(outputSettings: PBXOutputSettings()).generateReferences(proj: $0.xcodeProj.pbxproj)
        }

        let (autogeneratedXCTestPlanDescriptors, generateMetadata) = try autogeneratedXCTestPlanDescriptorsAndGenerateMetadata(
            graphTraverser: graphTraverser,
            generatedProjects: generatedProjects,
            sideTable: sideTable
        )

        return WorkspaceDescriptor(
            path: graphTraverser.workspace.path,
            xcworkspacePath: graphTraverser.workspace.xcWorkspacePath,
            xcworkspace: xcWorkspace,
            projectDescriptors: projects,
            schemeDescriptors: schemes,
            sideEffectDescriptors: [],
            workspaceSettingsDescriptor: workspaceSettingsGenerator.generateWorkspaceSettings(workspace: graphTraverser.workspace),
            autogeneratedXCTestPlanDescriptors: autogeneratedXCTestPlanDescriptors,
            generateMetadata: generateMetadata
        )
    }

    private func autogeneratedXCTestPlanDescriptorsAndGenerateMetadata(
        graphTraverser: GraphTraversing,
        generatedProjects: [AbsolutePath: GeneratedProject],
        sideTable: GraphSideTable
    ) throws -> ([AutogeneratedXCTestPlanDescriptor], GenerateMetadata) {
        
        let workspaceGeneratorPaths = GeneratorPaths(manifestDirectory: graphTraverser.workspace.path)
        let allTargets = graphTraverser.allInternalTargets()
        let rootPath = graphTraverser.workspace.xcWorkspacePath.parentDirectory

        func targetForVariableExpansion(target: String?) -> AutogeneratedXCTestPlanDescriptor.TestTarget? {
            guard
                let target,
                let graphTarget = allTargets.first(where: { $0.target.name == target })
            else { return nil }

            return descriptorTestTarget(rootPath: rootPath, generatedProjects: generatedProjects, target: (TestableTarget(stringLiteral: target), graphTarget))
        }

        var autogeneratedXCTestPlanDescriptors: [AutogeneratedXCTestPlanDescriptor] = []
        for autogeneratedTestPlan in graphTraverser.workspace.generationOptions.autogeneratedTestPlans {
            let path = try autogeneratedTestPlan.resolvePath(generatorPaths: workspaceGeneratorPaths)

            let configurationOptionsTargetForVariableExpansion = targetForVariableExpansion(target: autogeneratedTestPlan.configurationOptions?.targetForVariableExpansion)
            let defaultOptionsTargetForVariableExpansion = targetForVariableExpansion(target: autogeneratedTestPlan.defaultOptions?.targetForVariableExpansion)
            let testTargets = descriptorTestTargets(
                allTargets: allTargets,
                testTargets: autogeneratedTestPlan.testTargets,
                rootPath: rootPath,
                generatedProjects: generatedProjects
            )

            let testPlanDescriptor = AutogeneratedXCTestPlanDescriptor(
                path: path,
                configurationOptions: autogeneratedTestPlan.configurationOptions,
                defaultOptions: autogeneratedTestPlan.defaultOptions,
                configurationOptionsTargetForVariableExpansion: configurationOptionsTargetForVariableExpansion,
                defaultOptionsTargetForVariableExpansion: defaultOptionsTargetForVariableExpansion,
                testTargets: testTargets
            )
            autogeneratedXCTestPlanDescriptors.append(testPlanDescriptor)
        }

        let allTestTargets = descriptorTestTargets(allTargets: allTargets, testTargets: .all, rootPath: rootPath, generatedProjects: generatedProjects).mapTestTargets()

        let generateMetadata = GenerateMetadata(
            cacheEnabled: sideTable.workspace.cacheEnabled,
            focusedTargets: sideTable.workspace.focusedTargets,
            allTestTargets: allTestTargets
        )

        return (autogeneratedXCTestPlanDescriptors, generateMetadata)
    }

    private func descriptorTestTargets(
        allTargets: Set<GraphTarget>,
        testTargets: AutogeneratedTestPlan.TestTargets,
        rootPath: AbsolutePath,
        generatedProjects: [AbsolutePath: GeneratedProject],
    ) -> [AutogeneratedXCTestPlanDescriptor.TestTarget] {
        let targets: [(testableTarget: TestableTarget, graphTarget: GraphTarget)]

        switch testTargets {
        case .all:
            targets = allTargets.filter(\.target.product.testsBundle).map { graphTarget in
                (TestableTarget(target: TargetReference(stringLiteral: graphTarget.target.name)), graphTarget)
            }
        case let .testableTargets(testableTargets):
            targets = testableTargets.compactMap { testTarget in
                guard let graphTarget = allTargets.first(where: { $0.target.name == testTarget.target.targetName }) else { return nil }
                return (testTarget, graphTarget)
            }
        default:
            return []
        }

        let result = targets.compactMap { target in
            descriptorTestTarget(rootPath: rootPath, generatedProjects: generatedProjects, target: target)
        }

        return result.sorted(by: { $0.pbxTarget.name < $1.pbxTarget.name })
    }

    private func descriptorTestTarget(
        rootPath: AbsolutePath,
        generatedProjects: [AbsolutePath: GeneratedProject],
        target: (testableTarget: TestableTarget, graphTarget: GraphTarget)
    ) -> AutogeneratedXCTestPlanDescriptor.TestTarget? {

        let (testableTarget, graphTarget) = target
        let xcodeProjectPath = graphTarget.project.xcodeProjPath

        guard
            let generatedProject = generatedProjects[xcodeProjectPath],
            let pbxTarget = generatedProject.targets[graphTarget.target.name]
        else { return nil }

        let containerRelativePath = xcodeProjectPath.relative(to: rootPath).pathString

        return AutogeneratedXCTestPlanDescriptor.TestTarget(
            pbxTarget: pbxTarget,
            containerPath: "container:\(containerRelativePath)",
            isEnabled: !testableTarget.isSkipped,
            isParallelizable: testableTarget.isParallelizable
        )
    }

    /// Create a XCWorkspaceDataElement.file from a path string.
    ///
    /// - Parameter path: The relative path to the file
    private func workspaceFileElement(path: RelativePath) -> XCWorkspaceDataElement {
        let location = XCWorkspaceDataElementLocationType.group(path.pathString)
        let fileRef = XCWorkspaceDataFileRef(location: location)
        return .file(fileRef)
    }

    /// Sorting function for workspace data elements. It applies the following sorting criteria:
    ///  - Files sorted before groups.
    ///  - Groups sorted by name.
    ///  - Files sorted using the workspaceFilePathSort sort function.
    ///
    /// - Parameters:
    ///   - lhs: First file to be sorted.
    ///   - rhs: Second file to be sorted.
    /// - Returns: True if the first workspace data element should be before the second one.
    private func workspaceDataElementSort(lhs: XCWorkspaceDataElement, rhs: XCWorkspaceDataElement) -> Bool {
        switch (lhs, rhs) {
        case let (.file(lhsFile), .file(rhsFile)):
            return workspaceFilePathSort(
                lhs: lhsFile.location.path,
                rhs: rhsFile.location.path
            )
        case let (.group(lhsGroup), .group(rhsGroup)):
            return lhsGroup.location.path < rhsGroup.location.path
        case (.file, .group):
            return true
        case (.group, .file):
            return false
        }
    }

    /// Sorting function for workspace data file elements. It applies the following sorting criteria:
    ///  - Xcode projects are sorted after other files.
    ///  - Xcode projects are sorted by name.
    ///  - Other files are sorted by name.
    ///
    /// - Parameters:
    ///   - lhs: First file path to be sorted.
    ///   - rhs: Second file path to be sorted.
    /// - Returns: True if the first element should be sorted before the second.
    private func workspaceFilePathSort(lhs: String, rhs: String) -> Bool {
        let lhsIsXcodeProject = lhs.hasSuffix(".xcodeproj")
        let rhsIsXcodeProject = rhs.hasSuffix(".xcodeproj")

        switch (lhsIsXcodeProject, rhsIsXcodeProject) {
        case (true, true):
            return lhs < rhs
        case (false, false):
            return lhs < rhs
        case (true, false):
            return false
        case (false, true):
            return true
        }
    }

    private func recursiveChildElement(
        generatedProjects: [AbsolutePath: GeneratedProject],
        element: WorkspaceStructure.Element,
        path: AbsolutePath
    ) throws -> XCWorkspaceDataElement {
        switch element {
        case let .file(path: filePath):
            return workspaceFileElement(path: filePath.relative(to: path))

        case let .folderReference(path: folderPath):
            return workspaceFileElement(path: folderPath.relative(to: path))

        case let .group(name: name, path: groupPath, contents: contents):
            let location = XCWorkspaceDataElementLocationType.group(groupPath.relative(to: path).pathString)

            let groupReference = XCWorkspaceDataGroup(
                location: location,
                name: name,
                children: try contents.map {
                    try recursiveChildElement(
                        generatedProjects: generatedProjects,
                        element: $0,
                        path: groupPath
                    )
                }.sorted(by: workspaceDataElementSort)
            )

            return .group(groupReference)
        case let .virtualGroup(name, contents):
            return .group(
                .init(
                    location: .container(""), name: name,
                    children: try contents.map {
                        try recursiveChildElement(
                            generatedProjects: generatedProjects,
                            element: $0,
                            path: path
                        )
                    }.sorted(by: workspaceDataElementSort)))
        case let .project(path: projectPath):
            guard generatedProjects[projectPath] != nil else {
                throw WorkspaceDescriptorGeneratorError.projectNotFound(path: projectPath)
            }
            let relativePath = projectPath.relative(to: path)
            return workspaceFileElement(path: relativePath)
        }
    }
}
