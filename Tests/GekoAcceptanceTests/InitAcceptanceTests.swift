#if os(macOS)

import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import GekoSupportTesting
import XCTest
import XcodeProj

final class InitAcceptanceTestmacOSApp: GekoAcceptanceTestCase {
    func test_init_macos_app() async throws {
        try run(InitCommand.self, "--platform", "macos", "--name", "Test")
        try await run(BuildCommand.self)
    }
}

final class InitAcceptanceTestiOSApp: GekoAcceptanceTestCase {
    func test_init_ios_app() async throws {
        try run(InitCommand.self, "--platform", "ios", "--name", "My-App")
        try await run(BuildCommand.self)
    }
}

// TODO: Fix
// final class InitAcceptanceTesttvOSApp: GekoAcceptanceTestCase {
//    func test_init_tvos_app() async throws {
//        try run(InitCommand.self, "--platform", "tvos", "--name", "TvApp")
//        try await run(BuildCommand.self)
//    }
// }

final class InitAcceptanceTestSwiftUIiOSApp: GekoAcceptanceTestCase {
    func test_init_swift_ui_ios_app() async throws {
        try run(InitCommand.self, "--platform", "ios", "--name", "MyApp", "--template", "swiftui")
        try await run(BuildCommand.self)
    }
}

final class InitAcceptanceTestSwiftUImacOSApp: GekoAcceptanceTestCase {
    func test_init_swift_ui_macos_app() async throws {
        try run(InitCommand.self, "--platform", "macos", "--name", "MyApp", "--template", "swiftui")
        try await run(BuildCommand.self)
    }
}

// TODO: Fix
// final class InitAcceptanceTestSwiftUtvOSApp: GekoAcceptanceTestCase {
//    func test_init_swift_ui_tvos_app() async throws {
//        try run(InitCommand.self, "--platform", "tvos", "--name", "MyApp", "--template", "swiftui")
//        try await run(BuildCommand.self)
//    }
// }

#endif
