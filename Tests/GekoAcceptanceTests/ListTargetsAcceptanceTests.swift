#if os(macOS)

import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import GekoSupportTesting
import XcodeProj
import XCTest

final class ListTargetsAcceptanceTestiOSWorkspaceWithMicrofeatureArchitecture: GekoAcceptanceTestCase {
    func test_ios_workspace_with_microfeature_architecture() async throws {
        try setUpFixture(.iosWorkspaceWithMicrofeatureArchitecture)
        try await run(GenerateCommand.self)
        try listTargets(for: "UIComponents")
        try listTargets(for: "Core")
        try listTargets(for: "Data")
    }
}

extension GekoAcceptanceTestCase {
    fileprivate func listTargets(
        for framework: String
    ) throws {
        let frameworkXcodeprojPath = fixturePath.appending(
            components: [
                "Frameworks",
                "\(framework)Framework",
                "\(framework).xcodeproj",
            ]
        )

        try run(MigrationTargetsByDependenciesCommand.self, "-p", frameworkXcodeprojPath.pathString)
        XCTAssertStandardOutput(
            pattern:
            """
            "targetName" : "\(framework)"
            """
        )
    }
}

#endif
