#if os(macOS)

import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import GekoSupportTesting
import XCTest
import XcodeProj

 final class EditAcceptanceTestiOSAppWithHelpers: GekoAcceptanceTestCase {
     func test_ios_app_with_helpers() async throws {
         try setUpFixture(.iosAppWithHelpers)
         try await run(EditCommand.self)
         try await run(FetchCommand.self)
         try await run(GenerateCommand.self)
         try await run(BuildCommand.self)
     }
 }

 final class EditAcceptanceTestPlugin: GekoAcceptanceTestCase {
     func test_plugin() async throws {
         try setUpFixture(.plugin)
         try await run(EditCommand.self)
         try build(scheme: "LocalPlugins")
     }
 }

// final class EditAcceptanceTestAppWithPlugins: GekoAcceptanceTestCase {
//     func test_app_with_plugins() async throws {
//         try setUpFixture(.appWithPlugins)
//         try await run(FetchCommand.self)
//         try await run(EditCommand.self)
//         try build(scheme: "Manifests")
//         try build(scheme: "Plugins")
//         try build(scheme: "LocalPlugin")
//     }
// }
//
// TODO: Uses swift package from github
// final class EditAcceptanceTestAppWithSPMDependencies: GekoAcceptanceTestCase {
//     func test_app_with_spm_dependencies() async throws {
//         try setUpFixture(.appWithSpmDependencies)
//         try await run(EditCommand.self)
//         try await run(FetchCommand.self)
//         try await run(GenerateCommand.self)
//         try await run(BuildCommand.self)
//     }
// }

 extension GekoAcceptanceTestCase {
     fileprivate func build(scheme: String) throws {
         try System.shared.runAndPrint(
             [
                 "/usr/bin/xcrun",
                 "xcodebuild",
                 "clean",
                 "build",
                 "-scheme",
                 scheme,
                 "-workspace",
                 workspacePath.pathString,
             ]
         )
     }
}

#endif
