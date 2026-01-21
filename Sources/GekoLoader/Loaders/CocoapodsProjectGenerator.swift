import Foundation
import GekoCocoapods
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

final class CocoapodsProjectGenerator {
    let cocoapodsTargetGenerator = CocoapodsTargetGenerator()
    let sideEffectExecutor = SideEffectDescriptorExecutor()

    private let fileHandler: FileHandling

    init(fileHandler: FileHandling = FileHandler.shared) {
        self.fileHandler = fileHandler
    }

    func generateProject(
        spec: CocoapodsSpec,
        path: AbsolutePath,
        podspecPath: AbsolutePath,
        workspacePath: AbsolutePath,
        externalDependencies: [String: [TargetDependency]],
        appHostDependencyResolver: CocoapodsApphostDependencyResolving,
        projectOptionsProvider: CocoapodsProjectOptionsProvider,
        convertPathsToBuildableFolders: Bool,
        defaultForceLinking: CocoapodsDependencies.Linking?,
        forceLinking: [String : CocoapodsDependencies.Linking],
        sideTable: Atomic<GraphSideTable>
    ) throws -> (Project, [SideEffectDescriptor]) {
        let projectPath = path
        let sourceRootPath = podspecPath.parentDirectory
        let generatorPaths = GeneratorPaths(manifestDirectory: sourceRootPath)
        let derivedPath =
            projectPath
            .appending(component: Constants.DerivedDirectory.name)
        let moduleMapsPath =
            derivedPath
            .appending(component: Constants.DerivedDirectory.moduleMaps)
        let appHostPath = projectPath

        let specInfoProvider = CocoapodsSpecInfoProvider(spec: spec)

        let (cocoapodsTargets, targetSideEffects) = try allTargets(
            for: specInfoProvider,
            path: sourceRootPath,
            moduleMapsDir: moduleMapsPath,
            appHostDir: appHostPath,
            appHostDependencyResolver: appHostDependencyResolver,
            buildableFolderInference: convertPathsToBuildableFolders,
            defaultForceLinking: defaultForceLinking,
            forceLinking: forceLinking
        )

        try sideEffectExecutor.execute(sideEffects: targetSideEffects)

        saveGlobs(cocoapodsTargets: cocoapodsTargets, path: path, podspecPath: podspecPath, workspacePath: workspacePath, sideTable: sideTable)

        var convertedTargets: [Target] = []
        var sideEffects: [SideEffectDescriptor] = targetSideEffects
        for target in cocoapodsTargets {
            let target = try convertCocoapodsTarget(
                target,
                generatorPaths: generatorPaths,
                externalDependencies: externalDependencies
            )
            convertedTargets.append(target)
            sideEffects.append(contentsOf: targetSideEffects)
        }

        let options = projectOptionsProvider.provide(for: convertedTargets)

        let project = project(
            name: spec.name,
            with: convertedTargets,
            generatorPaths: generatorPaths,
            path: projectPath,
            workspacePath: workspacePath,
            podspecPath: podspecPath,
            options: options
        )

        return (project, sideEffects)
    }

    private func saveGlobs(
        cocoapodsTargets: [Target],
        path: AbsolutePath,
        podspecPath: AbsolutePath,
        workspacePath: AbsolutePath,
        sideTable: Atomic<GraphSideTable>
    ) {
        cocoapodsTargets.forEach { target in
            let generatorPaths = GeneratorPaths(manifestDirectory: podspecPath.parentDirectory)

            let sources = target.sources.map { source in
                let paths = source.paths.compactMap {
                    try? generatorPaths.resolve(path: $0).relative(to: workspacePath)
                }
                let excluding = source.excluding.compactMap {
                    try? generatorPaths.resolve(path: $0).relative(to: workspacePath)
                }
                
                return SourceFiles(paths: paths, excluding: excluding)
            }
            let resources = target.resources.compactMap { resource in
                try? generatorPaths.resolve(path: resource.path).relative(to: workspacePath)
            }
            
            sideTable.modify {
                $0.setSources(sources, path: path, name: target.name)
                $0.setResources(resources, path: path, name: target.name)
            }
        }
    }

    private func allTargets(
        for spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath,
        moduleMapsDir: AbsolutePath,
        appHostDir: AbsolutePath,
        appHostDependencyResolver: CocoapodsApphostDependencyResolving,
        buildableFolderInference: Bool,
        defaultForceLinking: CocoapodsDependencies.Linking?,
        forceLinking: [String : CocoapodsDependencies.Linking]
    ) throws -> ([ProjectDescription.Target], [SideEffectDescriptor]) {
        var targets: Set<ProjectDescription.Target> = []

        let (specTargets, specTargetSideEffects) =
            try cocoapodsTargetGenerator
            .nativeTargets(
                for: spec,
                path: path,
                moduleMapDir: moduleMapsDir,
                appHostDir: appHostDir,
                buildableFolderInference: buildableFolderInference,
                includeEmptyTargets: true,
                defaultForceLinking: defaultForceLinking,
                forceLinking: forceLinking
            )
        let (testTargets, testTargetSideEffects) =
            try cocoapodsTargetGenerator
            .testTargets(
                for: spec,
                path: path,
                moduleMapDir: moduleMapsDir,
                appHostDir: appHostDir,
                appHostDependencyResolver: appHostDependencyResolver,
                buildableFolderInference: buildableFolderInference,
                includeEmptyTargets: true,
                defaultForceLinking: defaultForceLinking,
                forceLinking: forceLinking
            )
        let (appTargets, appTargetSideEffects) =
            try cocoapodsTargetGenerator
            .appTargets(
                for: spec,
                path: path,
                moduleMapDir: moduleMapsDir,
                appHostDir: appHostDir,
                buildableFolderInference: buildableFolderInference,
                includeEmptyTargets: true,
                defaultForceLinking: defaultForceLinking,
                forceLinking: forceLinking
            )

        targets.formUnion(specTargets)
        targets.formUnion(testTargets)
        targets.formUnion(appTargets)

        return (
            Array(targets),
            specTargetSideEffects + testTargetSideEffects + appTargetSideEffects
        )
    }

    private func project(
        name: String,
        with targets: [Target],
        generatorPaths: GeneratorPaths,
        path: AbsolutePath,
        workspacePath: AbsolutePath,
        podspecPath: AbsolutePath,
        options: Project.Options
    ) -> Project {
        let xcodeProjectName = name

        // TODO: We need to work with the settings properly somehow
        let podsRoot = workspacePath.appending(components: ["Geko", "Dependencies", "Cocoapods"])
        let podsRootRelPath = podsRoot.relative(to: generatorPaths.manifestDirectory).pathString

        let settings = Settings(
            base: [
                "PODS_TARGET_SRCROOT": "${SRCROOT}",
                "PODS_ROOT": "${SRCROOT}/\(podsRootRelPath)",
                "PODS_BUILD_DIR": "${BUILD_DIR}",
            ],
            baseDebug: [:],
            configurations: [.release: nil, .debug: nil],
            defaultSettings: .recommended
        )

        return Project(
            path: path,
            sourceRootPath: generatorPaths.manifestDirectory,
            xcodeProjPath: path.appending(component: "\(xcodeProjectName).xcodeproj"),
            name: name,
            organizationName: nil,
            options: options,
            settings: settings,
            filesGroup: .group(name: "Project"),
            targets: targets,
            schemes: [],
            ideTemplateMacros: nil,
            additionalFiles: [
                FileElement.file(path: podspecPath)
            ],
            lastUpgradeCheck: nil,
            isExternal: false,
            projectType: .cocoapods,
            podspecPath: podspecPath
        )
    }

    private func convertCocoapodsTarget(
        _ target: consuming ProjectDescription.Target,
        generatorPaths: GeneratorPaths,
        externalDependencies: [String: [TargetDependency]]
    ) throws -> Target {
        target.dependencies = target.dependencies.map { dep -> ProjectDescription.TargetDependency in
            if case let .external(name, condition) = dep {
                if externalDependencies[name] != nil {
                    return dep
                } else {
                    return .local(name: name, condition: condition)
                }
            }
            return dep
        }

        try target.resolvePaths(generatorPaths: generatorPaths)

        return target
    }
}

extension ProjectDescription.Target: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(destinations)
        hasher.combine(product)
        hasher.combine(bundleId)
        hasher.combine(productName)
        hasher.combine(environmentVariables)
    }
}
