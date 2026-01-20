import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// Project mapper that sets `ENABLE_ONLY_ACTIVE_RESOURCES` build setting for bundle targets
///
/// `ENABLE_ONLY_ACTIVE_RESOURCES` - Omit inapplicable resources when building for a single device.
/// For example, when building for a device with a Retina display, exclude 1x resources. Default `YES`
public final class ResourceBundleActiveResourcesProjectMapper: ProjectMapping {

    private let onlyActiveResources: Bool

    public init(onlyActiveResources: Bool) {
        self.onlyActiveResources = onlyActiveResources
    }

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        guard !onlyActiveResources else { return [] }

        for targetIndex in 0 ..< project.targets.count {
            var target = project.targets[targetIndex]
            guard target.product == .bundle else { continue }

            target = target.with(additionalSettings: [
                "ENABLE_ONLY_ACTIVE_RESOURCES": "NO"
            ])
            project.targets[targetIndex] = target
        }
        return []
    }
}
