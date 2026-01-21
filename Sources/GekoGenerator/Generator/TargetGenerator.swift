import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription
import XcodeProj

protocol TargetGenerating: AnyObject {
    func generateTarget(
        target: Target,
        project: Project,
        pbxproj: PBXProj,
        pbxProject: PBXProject,
        projectSettings: Settings,
        fileElements: ProjectFileElements,
        path: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws -> PBXNativeTarget

    func generateAggregateTarget(
        target: Target,
        project: Project,
        pbxproj: PBXProj,
        pbxProject: PBXProject,
        projectSettings: Settings,
        fileElements: ProjectFileElements,
        path: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws -> PBXAggregateTarget?

    func generateTargetDependencies(
        path: AbsolutePath,
        targets: [Target],
        nativeTargets: [String: PBXNativeTarget],
        graphTraverser: GraphTraversing
    ) throws

    func generateAggregateTargetDependencies(
        path: AbsolutePath,
        targets: [Target],
        aggregateTargets: [String: PBXAggregateTarget],
        nativeTargets: [String: PBXTarget],
        graphTraverser: GraphTraversing
    ) throws
}

final class TargetGenerator: TargetGenerating {
    // MARK: - Attributes

    let configGenerator: ConfigGenerating
    let buildPhaseGenerator: BuildPhaseGenerating
    let linkGenerator: LinkGenerating
    let fileGenerator: FileGenerating
    let buildRulesGenerator: BuildRulesGenerating

    // MARK: - Init

    init(
        configGenerator: ConfigGenerating = ConfigGenerator(),
        fileGenerator: FileGenerating = FileGenerator(),
        buildPhaseGenerator: BuildPhaseGenerating = BuildPhaseGenerator(),
        linkGenerator: LinkGenerating = LinkGenerator(),
        buildRulesGenerator: BuildRulesGenerating = BuildRulesGenerator()
    ) {
        self.configGenerator = configGenerator
        self.fileGenerator = fileGenerator
        self.buildPhaseGenerator = buildPhaseGenerator
        self.linkGenerator = linkGenerator
        self.buildRulesGenerator = buildRulesGenerator
    }

    // MARK: - TargetGenerating

    func generateAggregateTarget(
        target: Target,
        project: Project,
        pbxproj: PBXProj,
        pbxProject: PBXProject,
        projectSettings: Settings,
        fileElements: ProjectFileElements,
        path _: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws -> PBXAggregateTarget? {
        guard target.product == .aggregateTarget else { return nil }

        let pbxTarget = PBXAggregateTarget(
            name: target.name,
            productName: target.productName
        )

        pbxproj.add(object: pbxTarget)
        pbxProject.targets.append(pbxTarget)

        /// Pre actions
        try buildPhaseGenerator.generateScripts(
            target.scripts.preScripts,
            pbxTarget: pbxTarget,
            pbxproj: pbxproj,
            sourceRootPath: project.sourceRootPath
        )

        /// Build configuration
        try configGenerator.generateTargetConfig(
            target,
            project: project,
            pbxTarget: pbxTarget,
            pbxproj: pbxproj,
            projectSettings: projectSettings,
            fileElements: fileElements,
            graphTraverser: graphTraverser,
            sourceRootPath: project.sourceRootPath
        )

        /// Post actions
        try buildPhaseGenerator.generateScripts(
            target.scripts.postScripts,
            pbxTarget: pbxTarget,
            pbxproj: pbxproj,
            sourceRootPath: project.sourceRootPath
        )

        return pbxTarget
    }

    // swiftlint:disable:next function_body_length
    func generateTarget(
        target: Target,
        project: Project,
        pbxproj: PBXProj,
        pbxProject: PBXProject,
        projectSettings: Settings,
        fileElements: ProjectFileElements,
        path: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws -> PBXNativeTarget {
        /// Products reference.
        let productFileReference = fileElements.products[target.name]!

        /// Target
        let pbxTarget = PBXNativeTarget(
            name: target.name,
            buildConfigurationList: nil,
            buildPhases: [],
            buildRules: [],
            dependencies: [],
            productInstallPath: nil,
            productName: target.productName,
            product: productFileReference,
            productType: target.product.xcodeValue
        )
        pbxproj.add(object: pbxTarget)
        pbxProject.targets.append(pbxTarget)

        /// Pre actions
        try buildPhaseGenerator.generateScripts(
            target.scripts.preScripts,
            pbxTarget: pbxTarget,
            pbxproj: pbxproj,
            sourceRootPath: project.sourceRootPath
        )

        /// Build configuration
        try configGenerator.generateTargetConfig(
            target,
            project: project,
            pbxTarget: pbxTarget,
            pbxproj: pbxproj,
            projectSettings: projectSettings,
            fileElements: fileElements,
            graphTraverser: graphTraverser,
            sourceRootPath: project.sourceRootPath
        )

        /// Build phases
        try buildPhaseGenerator.generateBuildPhases(
            path: path,
            target: target,
            graphTraverser: graphTraverser,
            pbxTarget: pbxTarget,
            fileElements: fileElements,
            pbxproj: pbxproj
        )

        /// Links
        try linkGenerator.generateLinks(
            target: target,
            pbxTarget: pbxTarget,
            pbxproj: pbxproj,
            fileElements: fileElements,
            path: path,
            sourceRootPath: project.sourceRootPath,
            graphTraverser: graphTraverser
        )

        /// Post actions
        try buildPhaseGenerator.generateScripts(
            target.scripts.postScripts,
            pbxTarget: pbxTarget,
            pbxproj: pbxproj,
            sourceRootPath: project.sourceRootPath
        )

        try buildRulesGenerator.generateBuildRules(
            target: target,
            pbxTarget: pbxTarget,
            pbxproj: pbxproj
        )

        return pbxTarget
    }

    func generateTargetDependencies(
        path: AbsolutePath,
        targets: [Target],
        nativeTargets: [String: PBXNativeTarget],
        graphTraverser: GraphTraversing
    ) throws {
        for targetSpec in targets {
            let dependenciesAndConditions = graphTraverser.directLocalTargetDependencies(
                path: path,
                name: targetSpec.name
            ).sorted()

            for dependency in dependenciesAndConditions {
                let nativeTarget = nativeTargets[targetSpec.name]!
                let nativeDependency = nativeTargets[dependency.target.name]!
                let pbxTargetDependency = try nativeTarget.addDependency(target: nativeDependency)
                pbxTargetDependency?.applyCondition(dependency.condition, applicableTo: targetSpec)
            }
        }
    }

    func generateAggregateTargetDependencies(
        path: AbsolutePath,
        targets: [Target],
        aggregateTargets: [String: PBXAggregateTarget],
        nativeTargets: [String: PBXTarget],
        graphTraverser: GraphTraversing
    ) throws {
        let targets = targets.filter { $0.product == .aggregateTarget }

        for targetSpec in targets {
            let dependenciesAndConditions = graphTraverser.directLocalTargetDependencies(
                path: path,
                name: targetSpec.name
            ).sorted()

            for dependency in dependenciesAndConditions {
                let aggregateTarget = aggregateTargets[targetSpec.name]
                let nativeDependency = nativeTargets[dependency.target.name]!
                let pbxTargetDependency = try aggregateTarget?.addDependency(target: nativeDependency)
                pbxTargetDependency?.applyCondition(dependency.condition, applicableTo: targetSpec)
            }
        }
    }
}
