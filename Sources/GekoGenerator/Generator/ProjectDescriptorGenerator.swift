import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport
import XcodeProj

protocol ProjectDescriptorGenerating: AnyObject {
    /// Generates the given project.
    /// - Parameters:
    ///   - project: Project to be generated.
    ///   - graphTraverser: Graph traverser.
    ///   - verbose: Generate without logs
    /// - Returns: Generated project descriptor
    func generate(
        project: Project,
        graphTraverser: GraphTraversing,
        verbose: Bool
    ) throws -> ProjectDescriptor

    /// Generates the given project.
    /// - Parameters:
    ///   - project: Project to be generated.
    ///   - graphTraverser: Graph traverser.
    /// - Returns: Generated project descriptor
    func generate(
        project: Project,
        graphTraverser: GraphTraversing
    ) throws -> ProjectDescriptor
}

extension ProjectDescriptorGenerating {
    func generate(
        project: Project,
        graphTraverser: GraphTraversing
    ) throws -> ProjectDescriptor {
        try generate(
            project: project,
            graphTraverser: graphTraverser,
            verbose: true
        )
    }
}

final class ProjectDescriptorGenerator: ProjectDescriptorGenerating {
    // MARK: - ProjectConstants

    struct ProjectConstants {
        var objectVersion: UInt
        var archiveVersion: UInt

        static var xcode10: ProjectConstants {
            ProjectConstants(
                objectVersion: 50,
                archiveVersion: Xcode.LastKnown.archiveVersion
            )
        }

        static var xcode11: ProjectConstants {
            ProjectConstants(
                objectVersion: 52,
                archiveVersion: Xcode.LastKnown.archiveVersion
            )
        }

        static var xcode13: ProjectConstants {
            ProjectConstants(
                objectVersion: 55,
                archiveVersion: Xcode.LastKnown.archiveVersion
            )
        }
    }

    // MARK: - Attributes

    private let enforceExplicitDependencies: Bool

    /// Generator for the project targets.
    let targetGenerator: TargetGenerating

    /// Generator for the buildable folders.
    let buildableFolderGenerator: BuildableFolderGenerating

    /// Generator for the project configuration.
    let configGenerator: ConfigGenerating

    /// Generator for the project schemes.
    let schemeDescriptorsGenerator: SchemeDescriptorsGenerating

    // MARK: - Init

    /// Initializes the project generator with its attributes.
    ///
    /// - Parameters:
    ///   - targetGenerator: Generator for the project targets.
    ///   - configGenerator: Generator for the project configuration.
    ///   - schemeDescriptorsGenerator: Generator for the project schemes.
    init(
        enforceExplicitDependencies: Bool,
        targetGenerator: TargetGenerating = TargetGenerator(),
        buildableFolderGenerator: BuildableFolderGenerating = BuildableFolderGenerator(),
        configGenerator: ConfigGenerating = ConfigGenerator(),
        schemeDescriptorsGenerator: SchemeDescriptorsGenerating = SchemeDescriptorsGenerator()
    ) {
        self.enforceExplicitDependencies = enforceExplicitDependencies
        self.targetGenerator = targetGenerator
        self.buildableFolderGenerator = buildableFolderGenerator
        self.configGenerator = configGenerator
        self.schemeDescriptorsGenerator = schemeDescriptorsGenerator
    }

    // MARK: - ProjectGenerating

    // swiftlint:disable:next function_body_length
    func generate(
        project: Project,
        graphTraverser: GraphTraversing,
        verbose: Bool
    ) throws -> ProjectDescriptor {
        if verbose {
            clearingLogger.info("Generating project \(project.name)")
        }

        let selfRef = XCWorkspaceDataFileRef(location: .current(""))
        let selfRefFile = XCWorkspaceDataElement.file(selfRef)
        let workspaceData = XCWorkspaceData(children: [selfRefFile])
        let workspace = XCWorkspace(data: workspaceData)
        let projectConstants = try determineProjectConstants()
        let pbxproj = PBXProj(
            objectVersion: projectConstants.objectVersion,
            archiveVersion: projectConstants.archiveVersion,
            classes: [:]
        )

        let groups = ProjectGroups.generate(project: project, pbxproj: pbxproj)
        let fileElements = ProjectFileElements(enforceExplicitDependencies: enforceExplicitDependencies)
        try fileElements.generateProjectFiles(
            project: project,
            graphTraverser: graphTraverser,
            groups: groups,
            pbxproj: pbxproj
        )
        let configurationList = try configGenerator.generateProjectConfig(
            project: project,
            pbxproj: pbxproj,
            fileElements: fileElements
        )
        let pbxProject = try generatePbxproject(
            project: project,
            projectFileElements: fileElements,
            configurationList: configurationList,
            groups: groups,
            pbxproj: pbxproj
        )

        let nativeTargets = try generateTargets(
            project: project,
            pbxproj: pbxproj,
            pbxProject: pbxProject,
            fileElements: fileElements,
            graphTraverser: graphTraverser
        )

        let aggregatedTargets = try generateAggregateTargets(
            project: project,
            pbxproj: pbxproj,
            pbxProject: pbxProject,
            fileElements: fileElements,
            graphTraverser: graphTraverser,
            nativeTargets: nativeTargets
        )

        try buildableFolderGenerator.generateBuildableFolders(
            project: project,
            pbxproj: pbxproj,
            pbxProject: pbxProject,
            fileElements: fileElements
        )

        generateTestTargetIdentity(
            project: project,
            pbxproj: pbxproj,
            pbxProject: pbxProject
        )

        let generatedProject = GeneratedProject(
            pbxproj: pbxproj,
            path: project.xcodeProjPath,
            targets: nativeTargets.merging(aggregatedTargets, uniquingKeysWith: { current, _ in current }),
            name: project.xcodeProjPath.basename
        )

        let schemes = try schemeDescriptorsGenerator.generateProjectSchemes(
            project: project,
            generatedProject: generatedProject,
            graphTraverser: graphTraverser
        )

        let xcodeProj = XcodeProj(workspace: workspace, pbxproj: pbxproj)

        return ProjectDescriptor(
            path: project.path,
            xcodeprojPath: project.xcodeProjPath,
            xcodeProj: xcodeProj,
            schemeDescriptors: schemes,
            sideEffectDescriptors: []
        )
    }

    // MARK: - Fileprivate

    private func generatePbxproject(
        project: Project,
        projectFileElements: ProjectFileElements,
        configurationList: XCConfigurationList,
        groups: ProjectGroups,
        pbxproj: PBXProj
    ) throws -> PBXProject {
        let defaultKnownRegions = project.options.defaultKnownRegions ?? ["en", "Base"]
        let knownRegions = Set(defaultKnownRegions + projectFileElements.knownRegions).sorted()
        let developmentRegion = project.options.developmentRegion ?? Xcode.Default.developmentRegion
        let attributes = generateAttributes(project: project)
        let pbxProject = PBXProject(
            name: project.name,
            buildConfigurationList: configurationList,
            compatibilityVersion: Xcode.Default.compatibilityVersion,
            preferredProjectObjectVersion: nil,
            minimizedProjectReferenceProxies: nil,
            mainGroup: groups.sortedMain,
            developmentRegion: developmentRegion,
            hasScannedForEncodings: 0,
            knownRegions: knownRegions,
            productsGroup: groups.products,
            projectDirPath: "",
            projects: [],
            projectRoots: [],
            targets: [],
            attributes: attributes
        )
        pbxproj.add(object: pbxProject)
        pbxproj.rootObject = pbxProject
        return pbxProject
    }

    private func generateTargets(
        project: Project,
        pbxproj: PBXProj,
        pbxProject: PBXProject,
        fileElements: ProjectFileElements,
        graphTraverser: GraphTraversing
    ) throws -> [String: PBXTarget] {
        let targets = project.targets.filter { $0.product != .aggregateTarget }
        var nativeTargets: [String: PBXNativeTarget] = [:]
        for target in targets {
            let nativeTarget = try targetGenerator.generateTarget(
                target: target,
                project: project,
                pbxproj: pbxproj,
                pbxProject: pbxProject,
                projectSettings: project.settings,
                fileElements: fileElements,
                path: project.path,
                graphTraverser: graphTraverser
            )
            nativeTargets[target.name] = nativeTarget
        }

        /// Target dependencies
        try targetGenerator.generateTargetDependencies(
            path: project.path,
            targets: targets,
            nativeTargets: nativeTargets,
            graphTraverser: graphTraverser
        )
        return nativeTargets
    }

    private func generateAggregateTargets(
        project: Project,
        pbxproj: PBXProj,
        pbxProject: PBXProject,
        fileElements: ProjectFileElements,
        graphTraverser: GraphTraversing,
        nativeTargets: [String: PBXTarget]
    ) throws -> [String: PBXTarget] {
        let aggregateTargets = project.targets.filter { $0.product == .aggregateTarget }
        guard !aggregateTargets.isEmpty else { return [:] }
        var pbxAggregateTargets: [String: PBXAggregateTarget] = [:]

        for target in aggregateTargets {
            let aggregateTarget = try targetGenerator.generateAggregateTarget(
                target: target,
                project: project,
                pbxproj: pbxproj,
                pbxProject: pbxProject,
                projectSettings: project.settings,
                fileElements: fileElements,
                path: project.path,
                graphTraverser: graphTraverser
            )
            guard let aggregateTarget else { continue }
            pbxAggregateTargets[target.name] = aggregateTarget
        }

        try targetGenerator.generateAggregateTargetDependencies(
            path: project.path,
            targets: project.targets,
            aggregateTargets: pbxAggregateTargets,
            nativeTargets: nativeTargets,
            graphTraverser: graphTraverser
        )
        return pbxAggregateTargets
    }

    private func generateTestTargetIdentity(
        project _: Project,
        pbxproj: PBXProj,
        pbxProject: PBXProject
    ) {
        func testTargetName(_ target: PBXTarget) -> String? {
            guard let buildConfigurations = target.buildConfigurationList?.buildConfigurations else {
                return nil
            }

            return buildConfigurations.compactMap { $0.buildSettings["TEST_TARGET_NAME"]?.stringValue }.first
        }

        let testTargets = pbxproj.nativeTargets.filter { $0.productType == .uiTestBundle || $0.productType == .unitTestBundle }

        for testTarget in testTargets {
            guard let name = testTargetName(testTarget) else {
                continue
            }

            guard let target = pbxproj.targets(named: name).first else {
                continue
            }

            var attributes = pbxProject.targetAttributes[testTarget] ?? [:]

            attributes["TestTargetID"] = .targetReference(target)

            pbxProject.setTargetAttributes(attributes, target: testTarget)
        }
    }

    private func generateAttributes(project: Project) -> [String: ProjectAttribute] {
        var attributes: [String: ProjectAttribute] = [:]

        /// ODR tags
        let tags = project.targets.map { $0.resources.map(\.tags).flatMap { $0 } }.flatMap { $0 }
        let uniqueTags = Set(tags).sorted()

        if !uniqueTags.isEmpty {
            attributes["KnownAssetTags"] = .array(uniqueTags)
        }

        // BuildIndependentTargetsInParallel
        attributes["BuildIndependentTargetsInParallel"] = "YES"

        /// Organization name
        if let organizationName = project.organizationName {
            attributes["ORGANIZATIONNAME"] = .string(organizationName)
        }

        /// Last upgrade check
        if let lastUpgradeCheck = project.lastUpgradeCheck {
            attributes["LastUpgradeCheck"] = .string(lastUpgradeCheck.xcodeStringValue)
        }

        return attributes
    }

    private func determineProjectConstants() throws -> ProjectConstants {
        // TODO: Determine if this can be inferred by the set Xcode version
        .xcode13
    }
}
