import Foundation
import GekoCore
import GekoSupport
import ProjectDescription
import XcodeProj

@testable import GekoGenerator

extension WorkspaceDescriptor {
    public static func test(
        path: AbsolutePath = try! AbsolutePath(validatingAbsolutePath: "/Test"), // swiftlint:disable:this force_try
        // swiftlint:disable:next force_try
        xcworkspacePath: AbsolutePath = try! AbsolutePath(validatingAbsolutePath: "/Test/Project.xcworkspace"),
        projects: [ProjectDescriptor] = [],
        schemes: [SchemeDescriptor] = [],
        sideEffects: [SideEffectDescriptor] = []
    ) -> WorkspaceDescriptor {
        WorkspaceDescriptor(
            path: path,
            xcworkspacePath: xcworkspacePath,
            xcworkspace: XCWorkspace(),
            projectDescriptors: projects,
            schemeDescriptors: schemes,
            sideEffectDescriptors: sideEffects
        )
    }
}
