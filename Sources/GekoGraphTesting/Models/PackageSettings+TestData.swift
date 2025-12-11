import Foundation
import ProjectDescription
@testable import GekoGraph

extension PackageSettings {
    public static func test(
        productTypes: [String: Product] = [:],
        baseSettings: Settings = .test(),
        targetSettings: [String: Settings] = [:],
        projectOptions: [String: ProjectDescription.Project.Options] = [:]
    ) -> PackageSettings {
        PackageSettings(
            productTypes: productTypes,
            baseSettings: baseSettings,
            targetSettings: targetSettings,
            projectOptions: projectOptions
        )
    }
}
