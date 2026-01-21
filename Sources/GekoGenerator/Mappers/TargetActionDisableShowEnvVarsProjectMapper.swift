import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

/// This mapper takes the `Project` `disableShowEnvironmentVarsInScriptPhases` option and pushes it down into all of the `Target`s
/// shell script `TargetAction`s
public final class TargetActionDisableShowEnvVarsProjectMapper: ProjectMapping { // swiftlint:disable:this type_name
    public init() {}

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        for i in 0 ..< project.targets.count {
            project.targets[i].scripts = project.targets[i].scripts.map {
                var script = $0
                script.showEnvVarsInLog = !project.options.disableShowEnvironmentVarsInScriptPhases
                return script
            }
        }

        return []
    }
}
