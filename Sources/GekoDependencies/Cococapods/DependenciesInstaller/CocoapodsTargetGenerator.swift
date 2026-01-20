import Foundation
import GekoCocoapods
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

final class CocoapodsTargetGenerator {
    private let cocoapodsTargetGenerator = GekoCocoapods.CocoapodsTargetGenerator()
    private let sideEffectExecutor = SideEffectDescriptorExecutor()

    private let pathProvider: CocoapodsPathProviding
    private let fileHandler: FileHandling

    init(
        pathProvider: CocoapodsPathProviding,
        fileHandler: FileHandling = FileHandler.shared
    ) {
        self.pathProvider = pathProvider
        self.fileHandler = fileHandler
    }

    func generateGraph(
        from spec: CocoapodsSpec,
        for path: AbsolutePath,
        subspecs: Set<String>,
        defaultForceLinking: CocoapodsDependencies.Linking?,
        forceLinking: [String: CocoapodsDependencies.Linking] = [:]
    ) throws -> DependenciesGraph {
        let specInfoProvider = CocoapodsSpecInfoProvider(spec: spec, subspecs: subspecs)

        let podsRoot = pathProvider.dependenciesDir

        let targetSupportDir =
            pathProvider
            .dependencyTargetSupportDir(name: spec.name)
        let frameworkBundlesPath = pathProvider.frameworkBundlesDir

        let prebuiltTargets = try prebuiltTargets(
            spec: specInfoProvider,
            path: path,
            frameworkBundlesPath: frameworkBundlesPath
        )

        var result = try nativeTargets(
            for: specInfoProvider,
            path: path,
            targetSupportDir: targetSupportDir,
            podsRoot: podsRoot,
            defaultForceLinking: defaultForceLinking,
            forceLinking: forceLinking
        ).deepMerging(with: prebuiltTargets)

        if result.externalDependencies[spec.name] == nil {
            result = .init(
                externalDependencies: [spec.name: []],
                externalProjects: [:],
                externalFrameworkDependencies: [:],
                tree: [spec.name: treeDependency(from: specInfoProvider)]
            )
        }

        return result
    }
}

extension CocoapodsTargetGenerator {
    private func nativeTargets(
        for spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath,
        targetSupportDir: AbsolutePath,
        podsRoot: AbsolutePath,
        defaultForceLinking: CocoapodsDependencies.Linking?,
        forceLinking: [String : CocoapodsDependencies.Linking]
    ) throws -> DependenciesGraph {
        let (nativeTargets, sideEffects) = try cocoapodsTargetGenerator.nativeTargets(
            for: spec,
            path: path,
            moduleMapDir: targetSupportDir,
            appHostDir: targetSupportDir,
            buildableFolderInference: false,
            defaultForceLinking: defaultForceLinking,
            forceLinking: forceLinking
        )
        try sideEffectExecutor.execute(sideEffects: sideEffects)

        if nativeTargets.isEmpty {
            return .none
        }

        let podsRootRelPath = podsRoot.relative(to: path).pathString

        let settings = Settings.settings(
            base: [
                "PODS_TARGET_SRCROOT": "${SRCROOT}",
                "PODS_ROOT": "${PROJECT_DIR}/\(podsRootRelPath)",
                "PODS_BUILD_DIR": "${BUILD_DIR}",
            ],
            debug: [:],
            release: [:],
            defaultSettings: .recommended
        )

        var project = Project(
            name: spec.name,
            options: .options(
                automaticSchemesOptions: .disabled,
                disableBundleAccessors: true
            ),
            settings: settings,
            targets: nativeTargets
        )
        project.projectType = .cocoapods

        return .init(
            externalDependencies: [
                spec.name: project.targets
                    .map { TargetDependency.project(target: $0.name, path: path) }
            ],
            externalProjects: [path: project],
            externalFrameworkDependencies: [:],
            tree: [spec.name: treeDependency(from: spec)]
        )
    }

    private func treeDependency(from spec: CocoapodsSpecInfoProvider) -> DependenciesGraph.TreeDependency {
        .init(
            version: spec.version,
            dependencies: Array(spec.dependencies().values.flatMap { $0 })
        )
    }
}

// MARK: - Prebuilt targets

extension CocoapodsTargetGenerator {
    fileprivate func prebuiltTargets(
        spec: CocoapodsSpecInfoProvider,
        path: AbsolutePath,
        frameworkBundlesPath: AbsolutePath
    ) throws -> DependenciesGraph {
        let (targets, dependencies) =
            try cocoapodsTargetGenerator
            .binaryTargets(for: spec, path: path)

        if targets.isEmpty {
            return .none
        }

        // let convertedDependencies = convertDependencies(from: dependencies)
        let convertedDependencies = dependencies
        let convertedTargets = try convertCocoapodsPrecompiledTargets(
            frameworkBundlesPath: frameworkBundlesPath,
            targets
        )

        var frameworkDependencies: [FilePath: [TargetDependency]] = [:]

        for target in convertedTargets {
            switch target {
            case let .framework(path, _, _),
                let .xcframework(path, _, _):
                frameworkDependencies[path] = convertedDependencies
            default:
                break
            }
        }

        return .init(
            externalDependencies: [
                spec.name: convertedTargets
            ],
            externalProjects: [:],
            externalFrameworkDependencies: frameworkDependencies,
            tree: [spec.name: treeDependency(from: spec)]
        )
    }

    private func convertCocoapodsPrecompiledTargets(
        frameworkBundlesPath: AbsolutePath,
        _ targets: [CocoapodsPrecompiledTarget]
    ) throws -> [TargetDependency] {
        var result: [TargetDependency] = []

        for target in targets {
            switch target {
            case .xcframework(let path, let condition):
                result.append(.xcframework(path: path, status: .required, condition: condition))
            case .framework(let path, let condtition):
                result.append(.framework(path: path, status: .required, condition: condtition))
            case .bundle(let path, let condition):
                let newPath = frameworkBundlesPath.appending(component: path.basename)
                try fileHandler.copy(from: path, to: newPath)
                result.append(.bundle(path: newPath, condition: condition))
            case .library(path: let path, condition: let condition):
                result.append(.library(path: path, publicHeaders: path.parentDirectory, swiftModuleMap: nil, condition: condition))
            }
        }

        return result
    }
}
