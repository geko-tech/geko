import Foundation
import struct ProjectDescription.AbsolutePath
import GekoMigration
import GekoSupport

class MigrationCheckEmptyBuildSettingsService {
    // MARK: - Attributes

    private let emptyBuildSettingsChecker: EmptyBuildSettingsChecking

    // MARK: - Init

    init(emptyBuildSettingsChecker: EmptyBuildSettingsChecking = EmptyBuildSettingsChecker()) {
        self.emptyBuildSettingsChecker = emptyBuildSettingsChecker
    }

    // MARK: - Internal

    func run(xcodeprojPath: AbsolutePath, target: String?) throws {
        try emptyBuildSettingsChecker.check(xcodeprojPath: xcodeprojPath, targetName: target)
    }
}
