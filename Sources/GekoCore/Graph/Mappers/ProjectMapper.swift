import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

public protocol ProjectMapping {
    func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor]
}

public class SequentialProjectMapper: ProjectMapping {
    let mappers: [ProjectMapping]

    public init(mappers: [ProjectMapping]) {
        self.mappers = mappers
    }

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        var sideEffects: [SideEffectDescriptor] = []
        for mapper in mappers {
            let newSideEffects = try mapper.map(
                project: &project,
                sideTable: &sideTable
            )
            sideEffects.append(contentsOf: newSideEffects)
        }

        return sideEffects
    }
}

public class TargetProjectMapper: ProjectMapping {
    private let mapper: TargetMapping

    public init(mapper: TargetMapping) {
        self.mapper = mapper
    }

    public func map(
        project: inout Project,
        sideTable: inout ProjectSideTable
    ) throws -> [SideEffectDescriptor] {
        var results = (targets: [Target](), sideEffects: [SideEffectDescriptor]())
        results = try project.targets.reduce(into: results) { results, target in
            let (updatedTarget, sideEffects) = try mapper.map(target: target)
            results.targets.append(updatedTarget)
            results.sideEffects.append(contentsOf: sideEffects)
        }
        project = project.with(targets: results.targets)
        return results.sideEffects
    }
}
