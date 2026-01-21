import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// Project mapper that sets additional compiler flags for coverage profile generation
///
/// Swiftc
/// `-Xfrontend -profile-generate` Generate instrumented code to collect execution counts
/// `-Xfrontend -profile-coverage-mapping` Generate coverage data for use with profiled execution counts
///
/// Clang
/// `-fprofile-instr-generate` Generate instrumented code to collect execution counts into default.profraw file
/// `-fcoverage-mapping` Generate coverage mapping to enable code coverage analysis
public final class ExportCoverageProfilesProjectMapper: ProjectMapping {

    private let exportCoverageProfiles: Bool

    public init(exportCoverageProfiles: Bool) {
        self.exportCoverageProfiles = exportCoverageProfiles
    }

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        guard exportCoverageProfiles else { return [] }

        for targetIndex in 0 ..< project.targets.count {
            var target = project.targets[targetIndex]
            guard target.product == .staticFramework || target.product == .framework else { continue }

            target = target.with(additionalSettings: [
                "OTHER_SWIFT_FLAGS": .array([
                    "-Xfrontend", "-profile-generate",
                    "-Xfrontend", "-profile-coverage-mapping"
                ]),
                "OTHER_CFLAGS": .array([
                    "-fprofile-instr-generate",
                    "-fcoverage-mapping"
                ])
            ], combineEqualSettings: true)
            project.targets[targetIndex] = target
        }
        return []
    }
}
