import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import XCTest

/// Build projects using Geko build
final class BuildAcceptanceTestWithTemplates: GekoAcceptanceTestCase {
    func test_with_templates() async throws {
        try run(InitCommand.self, "--platform", "ios", "--name", "MyApp")
        try await run(GenerateCommand.self)
        try await run(BuildCommand.self)
        try await run(BuildCommand.self, "MyApp")
        try await run(BuildCommand.self, "MyApp", "--configuration", "Debug")
    }
}

final class BuildAcceptanceTestAppWithFrameworkAndTests: GekoAcceptanceTestCase {
    func test_with_framework_and_tests() async throws {
        try setUpFixture(.appWithFrameworkAndTests)
        try await run(GenerateCommand.self)
        try await run(BuildCommand.self)
        try await run(BuildCommand.self, "App")
        try await run(BuildCommand.self, "AppCustomScheme")
        try await run(BuildCommand.self, "App-Workspace")
    }
}

// TODO: Fix -> This currently doesn't build because of a misconfig in Github actions where the tvOS platform is not available
// final class BuildAcceptanceTestAppWithTests: GekoAcceptanceTestCase {
//    func test() async throws {
//        try setUpFixture("app_with_tests")
//        try await run(GenerateCommand.self)
//        try await run(BuildCommand.self)
//        try await run(BuildCommand.self, "App")
//        try await run(BuildCommand.self, "App-Workspace-iOS")
//        try await run(BuildCommand.self, "App-Workspace-macOS")
//        try await run(BuildCommand.self, "App-Workspace-tvOS")
//    }
// }

// TODO: Uses swift package from github
// final class BuildAcceptanceTestFrameworkWithSwiftMacroIntegratedWithStandardMethod: GekoAcceptanceTestCase {
//     func test_framework_with_swift_macro_integrated_with_standard_method() async throws {
//         try setUpFixture(.frameworkWithSwiftMacro)
//         try await run(GenerateCommand.self)
//         try await run(BuildCommand.self, "Framework")
//     }
// }

// TODO: Uses swift package from github
// final class BuildAcceptanceTestFrameworkWithSwiftMacroIntegratedWithXcodeProjPrimitives: GekoAcceptanceTestCase {
//     func test_framework_with_swift_macro_integrated_with_xcode_proj_primitives() async throws {
//         try setUpFixture(.frameworkWithNativeSwiftMacro)
//         try await run(FetchCommand.self)
//         try await run(BuildCommand.self, "Framework", "--platform", "macos")
//         try await run(BuildCommand.self, "Framework", "--platform", "ios")
//     }
// }

// TODO: Requires watchOS runtime, which is missing on CI
// final class BuildAcceptanceTestMultiplatformAppWithExtensions: GekoAcceptanceTestCase {
//     func test() async throws {
//         try setUpFixture(.multiplatformAppWithExtension)
//         try await run(GenerateCommand.self)
//         try await run(BuildCommand.self, "App", "--platform", "ios")
//     }
// }

// TODO: Uses swift package from github
// final class BuildAcceptanceTestMultiplatformAppWithSDK: GekoAcceptanceTestCase {
//     func test() async throws {
//         try setUpFixture(.multiplatformAppWithSdk)
//         try await run(FetchCommand.self)
//         try await run(GenerateCommand.self)
//         try await run(BuildCommand.self, "App", "--platform", "macos")
//         try await run(BuildCommand.self, "App", "--platform", "ios")
//     }
// }

// TODO: Uses swift package from github
// final class BuildAcceptanceTestAppWithSPMDependencies: GekoAcceptanceTestCase {
//     func test() async throws {
//         try setUpFixture(.appWithSpmDependencies)
//         try await run(FetchCommand.self)
//         try await run(GenerateCommand.self)
//         try await run(BuildCommand.self)
//     }
// }
