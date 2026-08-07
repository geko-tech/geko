import Foundation
import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport
import GekoCocoapods
import GekoRegistry
import ProjectDescription

final class RegistryDependenciesInstaller {
    let fileHandler = FileHandler.shared
    let pathProvider: CocoapodsPathProviding

    init(
        pathProvider: CocoapodsPathProviding
    ) {
        self.pathProvider = pathProvider
    }

    func install(dependencies: consuming RegistryDependencyGraph) async throws -> GekoCore.DependenciesGraph {
        var result = GekoCore.DependenciesGraph.none

        for spec in dependencies.specs {
            result = try result.merging(with: convertSpec(spec: spec))
        }

        return result
    }

    func convertSpec(spec: RegistryPackage) -> GekoCore.DependenciesGraph {
        guard let pathString = spec.artifact.path else {
            fatalError("Only path registry specs are implemented")
        }
        let path = FilePath(pathString)

        var targets: [Target] = []

        for module in spec.modules {
            guard let product = Product(rawValue: module.product) else { continue }

            var dependencies: [TargetDependency] = []
            for dep in (module.dependencies ?? []) {
                switch dep.type {
                case .external:
                    dependencies.append(.external(name: dep.name))
                case .local:
                    dependencies.append(.target(name: dep.name))
                }
            }

            let target = ProjectDescription.Target(
                name: module.name,
                destinations: Destinations.iOS,
                product: product,
                sources: SourceFilesList(globs: module.sources ?? []),
                resources: ResourceFileElements(resources: module.resources ?? []),
                dependencies: dependencies,
                settings: module.settings
            )

            targets.append(target)
        }

        let project = Project(
            name: spec.name,
            targets: targets
        )

        return .init(
            externalDependencies: [
                spec.name: project.targets
                    .map { TargetDependency.project(target: $0.name, path: path) }
            ],
            externalProjects: [
                path: project
            ],
            externalFrameworkDependencies: [:],
            tree: [:]
        )
    }
}
