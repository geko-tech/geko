import ProjectDescription
import ProjectDescriptionHelpers

import ExampleGekoExecutablePlugin
import LocalPlugin

// Test plugins are loaded
let localHelper = LocalHelper(name: "LocalPlugin")
let remoteHelper = RemoteHelper(name: "RemotePlugin")

let project = Project.app(
    name: "GekoPluginTest",
    destinations: .iOS,
    additionalTargets: ["GekoPluginTestKit", "GekoPluginTestUI"]
)
