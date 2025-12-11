import ProjectDescription

extension Project {
    /// Helper function to create the Project for this ExampleApp
    public static func app(name: String, destinations: Destinations, additionalTargets _: [String]) -> Project {
        let mainTarget = Target(
            name: name,
            destinations: destinations,
            product: .app,
            bundleId: "app.geko.\(name)",
            infoPlist: .default,
            sources: ["Source/**"],
            resources: [
                "Resources/**",
            ],
            dependencies: []
        )

        return Project(
            name: name,
            organizationName: "geko.app",
            targets: [mainTarget]
        )
    }
}
