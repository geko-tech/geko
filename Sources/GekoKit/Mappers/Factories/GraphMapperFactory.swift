import Foundation
import GekoCache
import GekoCore
import GekoDependencies
import GekoGenerator
import GekoGraph
import GekoSupport
import ProjectDescription

/// The GraphMapperFactorying describes the interface of a factory of graph mappers.
/// Methods in the interface map with workflows exposed to the user.
protocol GraphMapperFactorying {
    ///  Returns the graph mapper that should be used for automation tasks such as build and test.
    /// - Returns: A graph mapper.
    func automation(
        config: Config,
        testsCacheDirectory: AbsolutePath,
        testPlan: String?,
        includedTargets: Set<String>,
        excludedTargets: Set<String>
    ) -> [GraphMapping]

    /// Returns the graph mapper for generating cacheable projects where some targets are pruned from the graph
    /// and execute targets scripts.
    func cache(
        config: Config,
        cacheProfile: ProjectDescription.Cache.Profile,
        focusedTargets: Set<String>,
        focusDirectDependencies: Bool,
        focusTests: Bool,
        unsafe: Bool,
        dependenciesOnly: Bool,
        scheme: String?
    ) -> [GraphMapping]

    /// Returns the grpah mapper for generating project with focus on targets without cache
    func focus(
        config: Config,
        focusedTargets: Set<String>,
        focusTests: Bool,
        scheme: String?
    ) -> [GraphMapping]

    /// Returns the default graph mapper that should be used from all the commands that require loading and processing the graph.
    /// - Returns: The default mapper.
    func `default`(
        config: Config
    ) -> [GraphMapping]
}

public final class GraphMapperFactory: GraphMapperFactorying {
    private let environment: Environmenting

    // MARK: - Init

    public init(environment: Environmenting = Environment.shared) {
        self.environment = environment
    }

    // MARK: - GraphMapperFactorying

    public func automation(
        config: Config,
        testsCacheDirectory _: AbsolutePath,
        testPlan: String?,
        includedTargets: Set<String>,
        excludedTargets: Set<String>
    ) -> [GraphMapping] {
        var mappers: [GraphMapping] = []
        mappers.append(
            FocusTargetsGraphMappers(
                testPlan: testPlan
            )
        )
        mappers.append(TreeShakePrunedTargetsGraphMapper())
        mappers.append(contentsOf: self.default(config: config))

        return mappers
    }

    public func cache(
        config: Config,
        cacheProfile: ProjectDescription.Cache.Profile,
        focusedTargets: Set<String>,
        focusDirectDependencies: Bool,
        focusTests: Bool,
        unsafe: Bool,
        dependenciesOnly: Bool,
        scheme: String?
    ) -> [GraphMapping] {
        var mappers: [GraphMapping] = []
        mappers.append(FocusedTargetsResolverGraphMapper(sources: focusedTargets, focusTests: focusTests, schemeName: scheme))
        mappers.append(FocusTargetsGraphMappers())
        mappers.append(TreeShakePrunedTargetsGraphMapper())
        mappers.append(UpdateWorkspaceProjectsGraphMapper())
        mappers.append(FocusedTargetsExpanderGraphMapper(
            focusDirectDependencies: focusDirectDependencies,
            unsafe: unsafe,
            dependenciesOnly: dependenciesOnly
        ))
        mappers.append(contentsOf: self.default(config: config))
        return mappers
    }

    public func focus(
        config: Config,
        focusedTargets: Set<String>,
        focusTests: Bool,
        scheme: String?
    ) -> [GraphMapping] {
        var mappers: [GraphMapping] = []
        mappers.append(FocusedTargetsResolverGraphMapper(sources: focusedTargets, focusTests: focusTests, schemeName: scheme))
        mappers.append(FocusTargetsGraphMappers())
        mappers.append(TreeShakePrunedTargetsGraphMapper())
        mappers.append(UpdateWorkspaceProjectsGraphMapper())
        mappers.append(contentsOf: self.default(config: config))
        return mappers
    }

    public func `default`(
        config: Config
    ) -> [GraphMapping] {
        var mappers: [GraphMapping] = []
        mappers.append(FocusTargetsGraphMappers())
        mappers.append(TreeShakePrunedTargetsGraphMapper())
        mappers.append(RunnableTargetsAstPathsAddingGraphMapper(
            addAstPathsToLinker: config.generationOptions.addAstPathsToLinker,
            modulesUseSubdirectory: config.generationOptions.enforceExplicitDependencies
        ))
        mappers.append(ModuleMapMapper())
        mappers.append(UpdateWorkspaceProjectsGraphMapper())
        mappers.append(PruneOrphanExternalTargetsGraphMapper())
        mappers.append(ExternalProjectsPlatformNarrowerGraphMapper())
        if config.generationOptions.enforceExplicitDependencies {
            mappers.append(ExplicitDependencyGraphMapper())
        }
        mappers.append(FrameworkSearchPathGraphMapper())
        mappers.append(CorrectSettingsGraphMapper())
        mappers.append(TransitiveResourcesGraphMapper())
        return mappers
    }
}
