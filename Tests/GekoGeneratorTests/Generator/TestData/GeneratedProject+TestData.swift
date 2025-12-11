import Foundation
import struct ProjectDescription.AbsolutePath
import XcodeProj
@testable import GekoGenerator

extension GeneratedProject {
    static func test(
        pbxproj: PBXProj = .init(),
        path: AbsolutePath = try! AbsolutePath(validating: "/project.xcodeproj"),
        targets: [String: PBXNativeTarget] = [:],
        name: String = "project.xcodeproj"
    ) -> GeneratedProject {
        GeneratedProject(pbxproj: pbxproj, path: path, targets: targets, name: name)
    }
}
