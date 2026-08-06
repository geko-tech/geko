import Foundation
import GekoCore
import GekoDependencies
import GekoLoader
import GekoGenerator
import GekoGraph
import GekoRegistry
import GekoSupport
import ProjectDescription
import Yams

final class RegistryPrepareService {
    private let dependenciesGraphController: DependenciesGraphControlling
    private let graphLoader: ManifestGraphLoading
    private let fileHandler: FileHandling

    init(
        dependenciesGraphController: DependenciesGraphControlling = DependenciesGraphController(),
        fileHandler: FileHandling = FileHandler.shared
        // graphLoader: ManifestGraphLoading = ManifestGraphLoader.init(
        //     manifestLoader: ManifestLoaderFactory().createManifestLoader(),
        //     workspaceMapper: SequentialWorkspaceMapper(mappers: []),
        //     graphMapper: SequentialGraphMapper([])
        // )
    ) {
        let contentHasher = ContentHasher()
        let projectMapperFactory = ProjectMapperFactory(contentHasher: contentHasher)
        let projectMappers = projectMapperFactory.default()
        let workspaceMapperFactory = WorkspaceMapperFactory(projectMapper: SequentialProjectMapper(mappers: projectMappers))
        let graphMapperFactory = GraphMapperFactory()
        // let graphMappers = graphMapperFactory.default(config: config)
        // let workspaceMappers = workspaceMapperFactory.default(config: config)
        // let graphMappers = graphMapperFactory.default(config: .init())
        // let workspaceMappers = workspaceMapperFactory.default(config: .init())
        let graphMappers: [GraphMapping] = []
        let workspaceMappers: [WorkspaceMapping] = [ResolvePathsWorkspaceMapper()]
        let manifestLoader = ManifestLoaderFactory().createManifestLoader()
        let manifestGraphLoader = ManifestGraphLoader(
            manifestLoader: manifestLoader,
            workspaceMapper: SequentialWorkspaceMapper(mappers: workspaceMappers),
            graphMapper: SequentialGraphMapper(graphMappers)
        )

        self.dependenciesGraphController = dependenciesGraphController
        self.graphLoader = manifestGraphLoader
        // self.graphLoader = graphLoader

        self.fileHandler = fileHandler
    }

    func loadRegistrySpec() throws -> [String: RegistrySpec] {
        let path = AbsolutePath.current.appending(components: ["Geko", "Registry.yml"])

        let data = try FileHandler.shared.readFile(path)
        let decoder = YAMLDecoder()
        let specs: [String: RegistrySpec] = try decoder.decode([String: RegistrySpec].self, from: data)

        return specs
    }

    func run() async throws {
        // let graph = try await graphLoader.load(path: .current)
        let (workspace, workspaceSideTable, sideEffects, lintingIssues, dependenciesGraph) = try await graphLoader.loadWorkspace(path: .current)

        let specs = try loadRegistrySpec()

        var packages: [RegistryPackage] = []

        for p in 0 ..< workspace.projects.count {
            guard let spec = specs[workspace.projects[p].name] else { continue }

            packages.append(
                convertProjectToPackage(workspace.projects[p], spec: spec)
            )
        }

        let path = AbsolutePath.current.appending(
            components: [
                Constants.GekoSandboxDirectory.name,
                Constants.GekoSandboxDirectory.registryDir
            ]
        )

        try? fileHandler.delete(path)
        try fileHandler.createFolder(path)

        var jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.prettyPrinted]

        for package in packages {
            let specPath = path.appending(component: "\(package.name).json")

            let jsonData = try jsonEncoder.encode(package)

            let jsonString = String(data: jsonData, encoding: .utf8)!

            try fileHandler.write(jsonString, path: specPath, atomically: true)
        }
    }

    func convertProjectToPackage(_ project: Project, spec: RegistrySpec) -> RegistryPackage {
        var modules: [RegistryPackage.Module] = []

        for target in project.targets {
            guard target.product.isPublishable else { continue }

            modules.append(
                RegistryPackage.Module(
                    name: target.name,
                    product: target.product.rawValue,
                    flavors: [
                        "source": .init(
                            sources: target.sources
                        )
                    ]
                )
            )
        }

        let dependencies = spec.dependencies.map { name, req in
            return RegistryPackage.PackageDependency(
                name: name,
                requirement: req
            )
        }

        return .init(
            name: project.name,
            version: spec.version,
            dependencies: dependencies,
            artifact: .init(path: project.path.pathString),
            modules: modules
        )
    }
}

private extension ProjectDescription.Product {
    var isPublishable: Bool {
        switch self {
        case .macro,
            .staticLibrary, .dynamicLibrary,
            .framework, .staticFramework,
            .bundle:
            return true
        case .app, .unitTests, .uiTests, .commandLineTool, .appExtension,
            .watch2App, .watch2Extension, 
            .tvTopShelfExtension,
            .messagesExtension, .stickerPackExtension, .appClip, 
            .xpc, .systemExtension, .extensionKitExtension, 
            .aggregateTarget:
            return false
        }
    }
}
