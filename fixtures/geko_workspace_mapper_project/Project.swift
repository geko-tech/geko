import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.app(
    name: "GekoWorkspaceMapperTest",
    destinations: .iOS,
    additionalTargets: ["GekoWorkspaceMapperTestKit", "GekoWorkspaceMapperTestUI"]
)
