import Foundation
import ProjectDescription
import XCTest

@testable import GekoGraph
@testable import GekoSupportTesting

final class ArchiveActionTests: GekoUnitTestCase {
    func test_codable() {
        // Given
        let subject = ArchiveAction(
            configuration: .configuration("name"),
            revealArchiveInOrganizer: true,
            customArchiveName: "archiveName",
            preActions: [
                .init(
                    title: "preActionTitle",
                    scriptText: "text",
                    target: nil,
                    shellPath: nil,
                    showEnvVarsInLog: false
                ),
            ],
            postActions: [
                .init(
                    title: "postActionTitle",
                    scriptText: "text",
                    target: nil,
                    shellPath: nil,
                    showEnvVarsInLog: true
                ),
            ]
        )

        // Then
        XCTAssertCodable(subject)
    }
}
