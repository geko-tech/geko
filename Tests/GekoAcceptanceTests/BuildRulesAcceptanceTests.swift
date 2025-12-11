#if os(macOS)

import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import GekoSupportTesting
import XcodeProj
import XCTest

final class BuildRulesAcceptanceTestAppWithBuildRules: GekoAcceptanceTestCase {
    func test_app_with_build_rules() async throws {
        try setUpFixture(.appWithBuildRules)
        try await run(GenerateCommand.self)
        try await run(BuildCommand.self)
        let xcodeproj = try XcodeProj(pathString: xcodeprojPath.pathString)
        let target = try XCTUnwrapTarget("App", in: xcodeproj)
        let buildRule = try XCTUnwrap(target.buildRules.first(where: { $0.name == "Process_InfoPlist.strings" }))
        XCTAssertEqual(buildRule.filePatterns, "*/InfoPlist.strings")
    }
}

#endif
