import Foundation
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
import XcodeProj
@testable import GekoGenerator

class MockTargetGenerator: TargetGenerating {
    var generateTargetStub: (() -> PBXNativeTarget)?

    func generateTarget(
        target: Target,
        project _: Project,
        pbxproj _: PBXProj,
        pbxProject _: PBXProject,
        projectSettings _: Settings,
        fileElements _: ProjectFileElements,
        path _: AbsolutePath,
        graphTraverser _: GraphTraversing
    ) throws -> PBXNativeTarget {
        generateTargetStub?() ?? PBXNativeTarget(name: target.name)
    }

    func generateTargetDependencies(
        path _: AbsolutePath,
        targets _: [Target],
        nativeTargets _: [String: PBXNativeTarget],
        graphTraverser _: GraphTraversing
    ) throws {}
    
    func generateAggregateTarget(
        target: Target,
        project: Project,
        pbxproj: PBXProj,
        pbxProject: PBXProject,
        projectSettings: Settings,
        fileElements: ProjectFileElements,
        path: AbsolutePath,
        graphTraverser: GraphTraversing
    ) throws -> PBXAggregateTarget? {
        return nil
    }
    
    func generateAggregateTargetDependencies(
        path: AbsolutePath,
        targets: [Target],
        aggregateTargets: [String: PBXAggregateTarget],
        nativeTargets: [String: PBXTarget],
        graphTraverser: GraphTraversing
    ) throws {}
}
