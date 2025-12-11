import Foundation
import struct ProjectDescription.AbsolutePath
@testable import GekoGraph

extension Plugins {
    public static func test(
        projectDescriptionHelpers: [ProjectDescriptionHelpersPlugin] = [],
        templatePaths: [AbsolutePath] = []
    ) -> Plugins {
        Plugins(
            projectDescriptionHelpers: projectDescriptionHelpers,
            templatePaths: templatePaths
        )
    }
}
