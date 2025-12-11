import ExampleGekoExecutablePlugin
import LocalPlugin
import ProjectDescription

extension Project {
    /// Helper function to create the Project for this ExampleApp
    public static func app(name: String, destinations: Destinations, additionalTargets _: [String]) -> Project {
        // Note: Testing importing of plugins in local helpers
        _ = LocalHelper(name: "local")
        _ = RemoteHelper(name: "remote")

        let mainTarget = Target(
            name: name,
            destinations: destinations,
            product: .app,
            bundleId: "io.geko.\(name)",
            infoPlist: .default,
            sources: ["Source/**"],
            resources: [
                "Resources/**",
            ],
            dependencies: []
        )

        return Project(
            name: name,
            organizationName: "geko.io",
            targets: [mainTarget]
        )
    }
}
