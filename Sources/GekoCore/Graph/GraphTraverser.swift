import Foundation
import GekoGraph
import GekoSupport
import ProjectDescription

// swiftlint:disable type_body_length
public class GraphTraverser: GraphTraversing {
    public var name: String { graph.name }
    public var path: AbsolutePath { graph.path }
    public var workspace: Workspace { graph.workspace }
    public var projects: [AbsolutePath: Project] { graph.projects }
    public var targets: [AbsolutePath: [String: Target]] { graph.targets }
    public var dependencies: [GraphDependency: Set<GraphDependency>] { graph.dependencies }
    public var frameworks: [AbsolutePath: GraphDependency] { graph.frameworks }
    public var libraries: [AbsolutePath: GraphDependency] { graph.libraries }
    public var xcframeworks: [AbsolutePath: GraphDependency] { graph.xcframeworks }
    public var externalDependenciesGraph: GekoGraph.DependenciesGraph {
        graph.externalDependenciesGraph
    }

    private let graph: Graph

    private var conditionMapCalculated = false
    private var conditionMap: [GraphDependency: [GraphDependency: PlatformCondition.CombinationResult]] = [:]

    private let systemFrameworkMetadataProvider: SystemFrameworkMetadataProviding = SystemFrameworkMetadataProvider()

    public required init(graph: Graph) {
        self.graph = graph
    }

    public func warmup() {
        if !conditionMapCalculated {
            let clock = WallClock()
            let timer = clock.startTimer()
            calculateCombinedConditionMap()
            logger.debug("condition map calculation took \(timer.stop())")
        }
    }

    public func rootTargets() -> Set<GraphTarget> {
        graph.workspace.projects.reduce(into: Set()) { result, path in
            result.formUnion(targets(at: path))
        }
    }

    public func allTargets() -> Set<GraphTarget> {
        allTargets(excludingExternalTargets: false)
    }

    public func allTargetsTopologicalSorted() throws -> [GraphTarget] {
        try topologicalSort(
            Array(allTargets()),
            successors: {
                directTargetDependencies(path: $0.path, name: $0.target.name).map(\.graphTarget)
            }
        ).reversed()
    }

    public func allInternalTargets() -> Set<GraphTarget> {
        allTargets(excludingExternalTargets: true)
    }

    public func allTestPlans() -> Set<TestPlan> {
        Set(schemes().flatMap { $0.testAction?.testPlans ?? [] })
    }

    public func rootProjects() -> Set<Project> {
        Set(graph.workspace.projects.compactMap { projects[$0] })
    }

    public func schemes() -> [Scheme] {
        projects.values.flatMap(\.schemes) + graph.workspace.schemes
    }

    public func precompiledFrameworksPaths() -> Set<AbsolutePath> {
        var result = Set<AbsolutePath>()

        for (key, value) in graph.dependencies {
            if case let GraphDependency.framework(path, _, _, _, _, _, _) = key {
                result.insert(path)
            }

            for dependency in value {
                if case let GraphDependency.framework(path, _, _, _, _, _, _) = dependency {
                    result.insert(path)
                }
            }
        }

        return result
    }

    public func targets(product: Product) -> Set<GraphTarget> {
        var filteredTargets: Set<GraphTarget> = Set()
        for (path, projectTargets) in targets {
            projectTargets.values.forEach { target in
                guard target.product == product else { return }
                guard let project = projects[path] else { return }
                filteredTargets.formUnion([GraphTarget(path: path, target: target, project: project)])
            }
        }
        return filteredTargets
    }

    public func target(path: AbsolutePath, name: String) -> GraphTarget? {
        guard let project = graph.projects[path], let target = graph.targets[path]?[name] else { return nil }
        return GraphTarget(path: path, target: target, project: project)
    }

    public func targets(at path: AbsolutePath) -> Set<GraphTarget> {
        guard let project = graph.projects[path] else { return Set() }
        guard let targets = graph.targets[path] else { return [] }
        return Set(targets.values.map { GraphTarget(path: path, target: $0, project: project) })
    }

    public func testPlan(name: String) -> TestPlan? {
        allTestPlans().first { $0.name == name }
    }

    private var allTargetDependenciesCache: [GraphDependency: Set<GraphDependency>] = [:]
    private let allTargetDependenciesLock = NSLock()

    public func allTargetDependencies(path: AbsolutePath, name: String) -> Set<GraphTarget> {
        let targetGraphDependency = GraphDependency.target(name: name, path: path)

        allTargetDependenciesLock.lock()
        defer { allTargetDependenciesLock.unlock() }

        if let cached = allTargetDependenciesCache[targetGraphDependency] {
            return cached.reduce(into: Set()) { result, dep in
                guard
                    case let .target(name, path, _) = dep,
                    let target = self.target(path: path, name: name)
                else { return }

                result.insert(target)
            }
        }

        func dfs(_ graphDependency: GraphDependency) {
            if allTargetDependenciesCache[graphDependency] != nil {
                return
            }

            guard let deps = graph.dependencies[graphDependency] else {
                allTargetDependenciesCache[graphDependency] = []
                return
            }

            allTargetDependenciesCache[graphDependency] = Set(deps)

            for dep in deps {
                dfs(dep)

                allTargetDependenciesCache[graphDependency]!.formUnion(allTargetDependenciesCache[dep]!)
            }

        }

        dfs(targetGraphDependency)

        return allTargetDependenciesCache[targetGraphDependency]!.reduce(into: Set()) { result, dep in
            guard
                case let .target(name, path, _) = dep,
                let target = self.target(path: path, name: name)
            else { return }

            result.insert(target)
        }
    }

    public func directTargetDependencies(path: AbsolutePath, name: String) -> Set<GraphTargetReference> {
        let target = GraphDependency.target(name: name, path: path)
        guard let dependencies = graph.dependencies[target]
        else { return [] }

        let targetDependencies =
            dependencies
            .compactMap { $0.targetDependency }

        return Set(convertToGraphTargetReferences(targetDependencies, for: target))
    }

    public func closestTargetDependencies(path: AbsolutePath, name: String) -> Set<GraphTargetReference> {
        let target = GraphDependency.target(name: name, path: path)

        var stack = Array(graph.dependencies[target] ?? [])
        var seen = Set<GraphDependency>()
        var closestTargetDependencies: Set<GraphDependency> = []

        while let next = stack.popLast() {
            seen.insert(next)

            if case .target = next {
                closestTargetDependencies.insert(next)
                continue
            }

            guard next.isPrecompiled && next.isLinkable else { continue }

            var depsToTraverse = Set(graph.dependencies[next] ?? [])
            depsToTraverse.subtract(seen)
            stack.append(contentsOf: depsToTraverse)
        }

        let targetDependencies = closestTargetDependencies.compactMap { $0.targetDependency }

        return Set(convertToGraphTargetReferences(targetDependencies, for: target))
    }

    public func directLocalTargetDependencies(path: AbsolutePath, name: String) -> Set<GraphTargetReference> {
        let target = GraphDependency.target(name: name, path: path)
        guard let dependencies = graph.dependencies[target],
            graph.projects[path] != nil
        else { return [] }

        let localTargetDependencies = dependencies.compactMap { $0.targetDependency }.filter { $0.path == path }

        return Set(convertToGraphTargetReferences(localTargetDependencies, for: target))
    }

    func convertToGraphTargetReferences(
        _ dependencies: [(name: String, path: AbsolutePath)],
        for target: GraphDependency
    ) -> [GraphTargetReference] {
        dependencies.compactMap { dependencyName, dependencyPath -> GraphTargetReference? in
            guard let projectDependencies = graph.targets[dependencyPath],
                let dependencyTarget = projectDependencies[dependencyName],
                let dependencyProject = graph.projects[dependencyPath]
            else {
                return nil
            }
            let condition = graph.dependencyConditions[(target, .target(name: dependencyTarget.name, path: dependencyPath))]
            let graphTarget = GraphTarget(path: dependencyPath, target: dependencyTarget, project: dependencyProject)
            return GraphTargetReference(target: graphTarget, condition: condition)
        }
    }

    public func resourceDependencies(path: AbsolutePath, name: String) -> Set<ResourceFileElement> {
        guard let target = graph.targets[path]?[name] else { return [] }
        guard target.supportsResources else { return [] }

        let dependencies = transitiveLinkableStaticDependencies(from: .target(name: name, path: path))

        var result = Set<ResourceFileElement>()
        for dep in dependencies {
            guard case let .target(name, path, _) = dep else { continue }
            guard let target = graph.targets[path]?[name] else { continue }
            result.formUnion(target.resources)
        }
        return result
    }

    public func resourceBundleDependencies(path: AbsolutePath, name: String) -> Set<GraphDependencyReference> {
        guard let target = graph.targets[path]?[name] else { return [] }
        guard target.supportsResources else { return [] }
        let targetGraphDependency: GraphDependency = .target(name: name, path: path)
        
        let canHostResources: (GraphDependency) -> Bool = {
            switch $0 {
            case let .xcframework(xcframework):
                return xcframework.linking == .dynamic
            case let .framework(_, _, _, _, linking, _, _):
                return linking == .dynamic
            case let .library(_, _, linking, _, _):
                return linking == .dynamic
            default:
                return self.target(from: $0)?.target.supportsResources == true
            }
        }
        
        resourceBundleDependenciesLock.lock()
        if let cached = resourceBundleDependenciesCache[targetGraphDependency] {
            resourceBundleDependenciesLock.unlock()
            return cached
        }
        resourceBundleDependenciesLock.unlock()
        
        let bundles: Set<GraphDependency> = bundlesSearch(
            rootDependency: targetGraphDependency,
            test: { isSpmTarget in !isSpmTarget },
            skip: canHostResources
        )
        
        let spmBundles: Set<GraphDependency>
        if canDependencyEmbedBundles(dependency: targetGraphDependency) {
            spmBundles = bundlesSearch(
                rootDependency: targetGraphDependency,
                test: { isSpmTarget in isSpmTarget },
                skip: canDependencyEmbedBundles
            )
        } else {
            spmBundles = []
        }
        
        let result = Set(
            bundles.union(spmBundles)
                .compactMap { dependencyReference(to: $0, from: .target(name: name, path: path)) }
        )
        
        resourceBundleDependenciesLock.lock()
        resourceBundleDependenciesCache[targetGraphDependency] = result
        resourceBundleDependenciesLock.unlock()
        
        return result
    }
    
    private var resourceBundleDependenciesCache: [GraphDependency: Set<GraphDependencyReference>] = [:]
    private let resourceBundleDependenciesLock = NSLock()
    
    private func bundlesSearch(
        rootDependency: GraphDependency,
        test: (_ isSpmTarget: Bool) -> Bool,
        skip: (GraphDependency) -> Bool
    ) -> Set<GraphDependency> {
        var visited: Set<GraphDependency> = []
        var result: Set<GraphDependency> = []
        
        func isSpmTarget(dependency: GraphDependency, isParentSpmTarget: Bool) -> Bool {
            if let target = self.target(from: dependency) {
                isParentSpmTarget || target.project.projectType == .spm
            } else {
                isParentSpmTarget
            }
        }
        
        func dfs(_ dependency: GraphDependency, isParentSpmTarget: Bool) {
            if visited.contains(dependency) {
                return
            }

            visited.insert(dependency)
            
            let isSpmTarget = isSpmTarget(dependency: dependency, isParentSpmTarget: isParentSpmTarget)
            
            if dependency != rootDependency && isDependencyResourceBundle(dependency: dependency) && test(isSpmTarget) {
                result.insert(dependency)
            }
            
            if dependency != rootDependency && skip(dependency) {
                return
            }
            
            guard let deps = self.graph.dependencies[dependency] else {
                return
            }
            
            for dep in deps {
                dfs(dep, isParentSpmTarget: isSpmTarget)
            }
        }
        
        dfs(rootDependency, isParentSpmTarget: false)
        
        return result
    }
    
    public func target(from dependency: GraphDependency) -> GraphTarget? {
        guard case let GraphDependency.target(name, path, _) = dependency else {
            return nil
        }
        guard let target = graph.targets[path]?[name] else { return nil }
        guard let project = graph.projects[path] else { return nil }
        return GraphTarget(path: path, target: target, project: project)
    }

    public func appExtensionDependencies(path: AbsolutePath, name: String) -> Set<GraphTargetReference> {
        let validProducts: [Product] = [
            .appExtension, .stickerPackExtension, .watch2Extension, .tvTopShelfExtension, .messagesExtension,
        ]
        return Set(
            directLocalTargetDependencies(path: path, name: name)
                .filter { validProducts.contains($0.target.product) }
        )
    }

    public func extensionKitExtensionDependencies(path: AbsolutePath, name: String) -> Set<GraphTargetReference> {
        let validProducts: [Product] = [
            .extensionKitExtension
        ]
        return Set(
            directLocalTargetDependencies(path: path, name: name)
                .filter { validProducts.contains($0.target.product) }
        )
    }

    public func appClipDependencies(path: AbsolutePath, name: String) -> GraphTargetReference? {
        directLocalTargetDependencies(path: path, name: name)
            .first { $0.target.product == .appClip }
    }

    public func buildsForMacCatalyst(path: AbsolutePath, name: String) -> Bool {
        guard target(path: path, name: name)?.target.supportsCatalyst ?? false else {
            return false
        }
        return allDependenciesSatisfy(from: .target(name: name, path: path)) { dependency in
            if let target = self.target(from: dependency) {
                return target.target.supportsCatalyst
            } else {
                // TODO: - Obtain this information from pre-compiled binaries
                // lipo -info should include "macabi" in the list of architectures
                return false
            }
        }
    }

    // Filter based on edges
    public func directStaticDependencies(path: AbsolutePath, name: String) -> Set<GraphDependencyReference> {
        Set(
            graph.dependencies[.target(name: name, path: path)]?
                .compactMap { (dependency: GraphDependency) -> GraphDependencyReference? in
                    guard case let GraphDependency.target(dependencyName, dependencyPath, _) = dependency,
                        let target = graph.targets[dependencyPath]?[dependencyName],
                        target.product.isStatic
                    else {
                        return nil
                    }

                    return dependencyReference(
                        to: .target(name: dependencyName, path: dependencyPath),
                        from: .target(name: name, path: path)
                    )
                }
                ?? []
        )
    }

    public func embeddableFrameworks(path: AbsolutePath, name: String) -> Set<GraphDependencyReference> {
        guard let target = target(path: path, name: name), canEmbedFrameworks(target: target.target) else { return Set() }

        var references: Set<GraphDependencyReference> = Set([])

        /// Precompiled frameworks
        var precompiledFrameworks = filterDependencies(
            from: .target(name: name, path: path),
            test: { $0.isPrecompiledDynamicAndLinkable },
            skip: or(canDependencyEmbedBinaries, isDependencyPrecompiledMacro)
        )
        // Skip merged precompiled libraries from merging into the runnable binary
        if case let .manual(dependenciesToMerge) = target.target.mergedBinaryType {
            precompiledFrameworks = precompiledFrameworks.filter {
                !isXCFrameworkMerged(dependency: $0, expectedMergedBinaries: dependenciesToMerge)
            }
        }
        references.formUnion(
            precompiledFrameworks.lazy.compactMap {
                self.dependencyReference(
                    to: $0,
                    from: .target(name: name, path: path)
                )
            }
        )

        /// Other targets' frameworks.
        var otherTargetFrameworks = filterDependencies(
            from: .target(name: name, path: path),
            test: isDependencyDynamicTarget,
            skip: canDependencyEmbedBinaries
        )

        if target.target.mergedBinaryType != .disabled {
            otherTargetFrameworks = otherTargetFrameworks.filter(isDependencyDynamicNonMergeableTarget)
        }

        references.formUnion(
            otherTargetFrameworks.lazy.compactMap {
                self.dependencyReference(
                    to: $0,
                    from: .target(name: name, path: path)
                )
            }
        )

        // Exclude any products embed in unit test host apps
        if target.target.product == .unitTests {
            if let hostApp = unitTestHost(path: path, name: name) {
                references.subtract(embeddableFrameworks(path: hostApp.path, name: hostApp.target.name))
            } else {
                references = Set()
            }
        }

        return references
    }

    public func searchablePathDependencies(path: AbsolutePath, name: String) throws -> Set<GraphDependencyReference> {
        let deps = try linkableDependencies(path: path, name: name, shouldExcludeNonLinkableDependencies: false)

        if let target = target(path: path, name: name),
            target.target.product == .unitTests || target.target.product == .uiTests,
            let appHostTarget = unitTestHost(path: path, name: name)
        {
            // unit and ui tests can use the same dependencies as in host app without linking them
            return deps.union(
                try searchablePathDependencies(path: appHostTarget.path, name: appHostTarget.target.name)
            )
        }

        return deps
    }

    public func linkableDependencies(path: AbsolutePath, name: String) throws -> Set<GraphDependencyReference> {
        try linkableDependencies(path: path, name: name, shouldExcludeNonLinkableDependencies: true)
    }

    public func linkableDependencies(
        path: AbsolutePath,
        name: String,
        shouldExcludeNonLinkableDependencies: Bool
    ) throws -> Set<GraphDependencyReference> {
        guard let target = target(path: path, name: name) else { return Set() }

        let targetGraphDependency = GraphDependency.target(name: name, path: path)

        // cache critical section start

        linkableDependenciesSearchCacheLock.lock()

        var result = linkableDependenciesSearch(from: targetGraphDependency)

        if shouldExcludeNonLinkableDependencies, target.target.product == .unitTests,
            let appHostTarget = unitTestHost(path: path, name: name) {
            let appHost = GraphDependency.target(
                name: appHostTarget.target.name,
                path: appHostTarget.path,
                status: .required
            )

            result.subtract(linkableDependenciesSearch(from: appHost).filter { !canDependencyLinkStaticProducts(dependency: $0) })
        }

        if !shouldExcludeNonLinkableDependencies {
            // static dependencies linked through dynamic libraries are available for import,
            // since they are linked as a one unit
            for dep in result {
                guard isDependencyDynamic(dependency: dep) else { continue }

                // add static dependencies of dynamic dependencies to result
                result.formUnion(
                    linkableDependenciesSearch(from: dep)
                        .filter { isDependencyStatic(dependency: $0) }
                )
            }
        }

        linkableDependenciesSearchCacheLock.unlock()

        // cache critical section end
        // no cache access is alowed below

        // if target cannot link static products, remove all transitive and non transitive static products
        if shouldExcludeNonLinkableDependencies, !target.target.canLinkStaticProducts() {
            result = Set(result.filter { !isDependencyStatic(dependency: $0) && !$0.isSdk })
            result.formUnion((dependencies[targetGraphDependency] ?? []).filter { $0.isSdk })
        }

        result = result.filter { isDependencyLinkable(dependency: $0) }

        var references: Set<GraphDependencyReference> = Set(result.compactMap {
            dependencyReference(to: $0, from: targetGraphDependency)
        })

        // AppClip dependencies
        if target.target.isAppClip {
            let path = try systemFrameworkMetadataProvider.loadMetadata(
                sdkName: "AppClip.framework",
                status: .required,
                platform: .iOS,
                source: .system
            ).path

            references.insert(
                GraphDependencyReference.sdk(
                    path: path,
                    status: .required,
                    source: .system,
                    condition: .when([.ios])
                )
            )
        }

        return references
    }

    private var linkableDependenciesSearchCache: [GraphDependency: Set<GraphDependency>] = [:]
    private var linkableDependenciesSearchCacheLock = NSLock()

    // helper that recursively searches for dependencies, that should be linked
    // WARNING: do not use without locking `linkableDependenciesSearchCacheLock` first
    private func linkableDependenciesSearch(from node: GraphDependency) -> Set<GraphDependency> {
        if let cached = linkableDependenciesSearchCache[node] {
            return cached
        }

        var appHostDependency: GraphDependency? = nil
        if
            case let .target(name, path, _) = node,
            let target = target(path:  path, name: name),
            target.target.product == .unitTests,
            let appHostTarget = unitTestHost(path: path, name: name)
        {
            appHostDependency = GraphDependency.target(
                name: appHostTarget.target.name,
                path: appHostTarget.path,
                status: .required
            )
        }

        let directDependencies = graph.dependencies[node] ?? []
        if directDependencies.isEmpty {
            linkableDependenciesSearchCache[node] = []
            return []
        }

        var result: Set<GraphDependency> = []

        // collect every transitive dependency
        for dependency in directDependencies {
            // skip macroses, and other dependencies that should not be linked
            guard isDependencyLinkable(dependency: dependency) || dependency == appHostDependency else { continue }

            result.insert(dependency)

            result.formUnion(linkableDependenciesSearch(from: dependency))
        }

        // Dependencies, that need to be removed from linking tree
        // For example, if App uses static framework Framework1 transitively through
        // dynamic framework, Framework1 should not be linked to App, because in such case
        // Framework1 will be linked two times to App and to dynamic framework
        var dependenciesToRemove = Set<GraphDependency>()
        var dependenciesToAdd = Set<GraphDependency>()
        for dependency in result {
            // process only dynamic dependencies
            guard canDependencyLinkStaticProducts(dependency: dependency) else { continue }

            var searchResult = linkableDependenciesSearch(from: dependency)
            searchResult = searchResult.filter {
                return !(isDependencyDynamic(dependency: $0) && directDependencies.contains($0))
            }
            // if dynamic dependency contains static dependency, which is gonna be removed, 
            // we should link such dependency, because otherwise there will be linking error
            // telling us that linker did not find symbol from removed static dependency
            if searchResult.contains(where: { isDependencyStatic(dependency: $0) }) {
                dependenciesToAdd.insert(dependency)
            }

            dependenciesToRemove.formUnion(searchResult)
        }

        result.subtract(dependenciesToRemove)

        // sdks and dynamic frameworks should be linked if they are used through static frameworks
        // so we walk through each static dependency and search for dynamic dependencies and sdks
        // (sdks are considered dynamic dependencies)
        for dependency in result {
            guard isDependencyStatic(dependency: dependency) else { continue }

            let searchResult = linkableDependenciesSearch(from: dependency)

            result.formUnion(searchResult.filter { isDependencyDynamic(dependency: $0) })
        }

        result.formUnion(dependenciesToAdd)

        // direct dependencies and sdks also should be added to linking, in case if we
        // removed them in code above
        result.formUnion(directDependencies.filter { isDependencyDynamic(dependency: $0) })

        linkableDependenciesSearchCache[node] = result

        return result
    }

    public func staticXCFrameworkDependencies(path: AbsolutePath, name: String) -> Set<GraphDependencyReference> {
        guard
            let target = target(path: path, name: name),
            target.target.product.isStatic
        else {
            return Set()
        }

        let dependencies = filterDependencies(
            from: .target(name: name, path: path),
            test: { dependency in
                switch dependency {
                case let .xcframework(xcframework):
                    return xcframework.linking == .static
                case .framework, .library, .bundle, .target, .sdk, .macro:
                    return false
                }
            }
        )
        return Set(
            dependencies.compactMap {
                dependencyReference(to: $0, from: .target(name: name, path: path))
            }
        )
    }

    public func copyProductDependencies(path: AbsolutePath, name: String) -> Set<GraphDependencyReference> {
        guard let target = target(path: path, name: name) else { return Set() }

        var dependencies = Set<GraphDependencyReference>()

        if target.target.product.isStatic {
            dependencies.formUnion(directStaticDependencies(path: path, name: name))
            dependencies.formUnion(staticPrecompiledXCFrameworksDependencies(path: path, name: name))
        }

        dependencies.formUnion(resourceBundleDependencies(path: path, name: name))

        return Set(dependencies)
    }

    public func directSwiftMacroExecutables(path: AbsolutePath, name: String) -> Set<GraphDependencyReference> {
        let dependencies = directTargetDependencies(path: path, name: name)
            .filter { $0.target.product == .macro }
            .map {
                GraphDependencyReference.product(
                    target: $0.target.name,
                    productName: $0.target.productName,
                    condition: .when([.macos])
                )
            }

        return Set(dependencies)
    }

    public func directSwiftMacroTargets(path: AbsolutePath, name: String) -> Set<GraphTargetReference> {
        let dependencies = directTargetDependencies(path: path, name: name)
            .filter { [.staticFramework, .framework, .dynamicLibrary, .staticLibrary].contains($0.target.product) }
            .filter { self.directSwiftMacroExecutables(path: $0.graphTarget.path, name: $0.graphTarget.target.name).count != 0 }
        return Set(dependencies)
    }

    private var allMacroTargetsCache: [GraphTarget: Set<GraphTarget>] = [:]
    private var allMacroTargetsLock = NSRecursiveLock()

    public func allSwiftMacroTargets(path: AbsolutePath, name: String) -> Set<GraphTarget> {
        allMacroTargetsLock.lock()
        defer { allMacroTargetsLock.unlock() }

        guard let target = target(path: path, name: name) else { return [] }

        if let cached = allMacroTargetsCache[target] {
            return cached
        }

        var result = Set<GraphTarget>()

        for dep in directTargetDependencies(path: path, name: name).map(\.graphTarget) {
            if [.staticFramework, .framework, .dynamicLibrary, .staticLibrary].contains(dep.target.product),
                directSwiftMacroExecutables(path: dep.path, name: dep.target.name).count != 0
            {
                result.insert(dep)
            }

            result.formUnion(allSwiftMacroTargets(path: dep.path, name: dep.target.name))
        }

        allMacroTargetsCache[target] = result
        return result
    }

    public func librariesPublicHeadersFolders(path: AbsolutePath, name: String) -> Set<AbsolutePath> {
        let dependencies = graph.dependencies[.target(name: name, path: path), default: []]
        let libraryPublicHeaders = dependencies.compactMap { dependency -> AbsolutePath? in
            guard case let GraphDependency.library(_, publicHeaders, _, _, _) = dependency else { return nil }
            return publicHeaders
        }
        return Set(libraryPublicHeaders)
    }

    public func librariesSearchPaths(path: AbsolutePath, name: String) throws -> Set<AbsolutePath> {
        let directDependencies = graph.dependencies[.target(name: name, path: path), default: []]
        let directDependenciesLibraryPaths = directDependencies.compactMap { dependency -> AbsolutePath? in
            guard case let GraphDependency.library(path, _, _, _, _) = dependency else { return nil }
            return path
        }

        // In addition to any directly linked libraries, search paths for any transitivley linked libraries
        // are also needed.
        let linkedLibraryPaths: [AbsolutePath] = try linkableDependencies(
            path: path,
            name: name,
            shouldExcludeNonLinkableDependencies: false
        ).compactMap { dependency in
            switch dependency {
            case let .library(path: path, linking: _, architectures: _, product: _, condition: _):
                return path
            default:
                return nil
            }
        }

        return Set((directDependenciesLibraryPaths + linkedLibraryPaths).compactMap { $0.removingLastComponent() })
    }

    public func librariesSwiftIncludePaths(path: AbsolutePath, name: String) -> Set<AbsolutePath> {
        let dependencies = graph.dependencies[.target(name: name, path: path), default: []]
        let librarySwiftModuleMapPaths = dependencies.compactMap { dependency -> AbsolutePath? in
            guard case let GraphDependency.library(_, _, _, _, swiftModuleMapPath) = dependency else { return nil }
            return swiftModuleMapPath
        }
        return Set(librarySwiftModuleMapPaths.compactMap { $0.removingLastComponent() })
    }

    public func runPathSearchPaths(path: AbsolutePath, name: String) -> Set<AbsolutePath> {
        guard let target = target(path: path, name: name),
            canEmbedFrameworks(target: target.target),
            target.target.product == .unitTests,
            unitTestHost(path: path, name: name) == nil
        else {
            return Set()
        }

        var references: Set<AbsolutePath> = Set([])

        let from = GraphDependency.target(name: name, path: path)
        let precompiledFrameworksPaths = filterDependencies(
            from: from,
            test: { $0.isPrecompiledDynamicAndLinkable },
            skip: canDependencyEmbedBinaries
        )
        .lazy
        .compactMap { (dependency: GraphDependency) -> AbsolutePath? in
            switch dependency {
            case let .xcframework(xcframework): return xcframework.path
            case let .framework(path, _, _, _, _, _, _): return path
            case .macro: return nil
            case .library: return nil
            case .bundle: return nil
            case .target: return nil
            case .sdk: return nil
            }
        }
        .map(\.parentDirectory)

        references.formUnion(precompiledFrameworksPaths)
        return references
    }

    public func hostTargetFor(path: AbsolutePath, name: String) -> GraphTarget? {
        guard let targets = graph.targets[path] else { return nil }
        guard let project = graph.projects[path] else { return nil }

        return targets.values.compactMap { target -> GraphTarget? in
            let dependencies = self.graph.dependencies[.target(name: target.name, path: path), default: Set()]
            let dependsOnTarget = dependencies.contains(where: { dependency in
                // swiftlint:disable:next identifier_name
                guard case let GraphDependency.target(_name, _path, _) = dependency else { return false }
                return _name == name && _path == path
            })
            let graphTarget = GraphTarget(path: path, target: target, project: project)
            return dependsOnTarget ? graphTarget : nil
        }.first
    }

    public func allProjectDependencies(path: AbsolutePath) throws -> Set<GraphDependencyReference> {
        let targets = targets(at: path)
        if targets.isEmpty { return Set() }
        var references: Set<GraphDependencyReference> = Set()

        // Linkable dependencies
        for target in targets {
            try references.formUnion(linkableDependencies(path: path, name: target.target.name))
            references.formUnion(embeddableFrameworks(path: path, name: target.target.name))
            references.formUnion(copyProductDependencies(path: path, name: target.target.name))
        }
        return references
    }

    public func dependsOnXCTest(path: AbsolutePath, name: String) -> Bool {
        guard let target = target(path: path, name: name) else {
            return false
        }
        if target.target.product.testsBundle {
            return true
        }
        if target.target.settings?.base["ENABLE_TESTING_SEARCH_PATHS"] == "YES" {
            return true
        }
        guard let directDependencies = dependencies[.target(name: name, path: path)] else {
            return false
        }
        return directDependencies.contains(where: { dependency in
            switch dependency {
            case .sdk(name: "XCTest", path: _, status: _, source: _):
                return true
            default:
                return false
            }
        })
    }

    public func dependsOnXCTestTransitively(path: AbsolutePath, name: String) -> Bool {
        let root = GraphDependency.target(name: name, path: path)

        let result = filterDependencies(
            from: root,
            test: { d in
                switch d {
                case let .target(name, path, _):
                    return dependsOnXCTest(path: path, name: name)
                case let .sdk(name, _, _, _):
                    return name == "XCTest" || name == "XCTest.framework"
                default:
                    return false
                }
            }
        )
        return !result.isEmpty
    }

    public func prebuiltDependencies(for rootDependency: GraphDependency) -> Set<GraphDependency> {
        filterDependencies(
            from: rootDependency,
            test: \.isPrecompiled
        )
    }

    public func targetsWithExternalDependencies() -> Set<GraphTarget> {
        allInternalTargets().filter { directTargetExternalDependencies(path: $0.path, name: $0.target.name).count != 0 }
    }

    public func directTargetExternalDependencies(path: AbsolutePath, name: String) -> Set<GraphTargetReference> {
        directTargetDependencies(path: path, name: name).filter(\.graphTarget.project.isExternal)
    }

    public func allExternalTargets() -> Set<GraphTarget> {
        let targets = graph.projects.compactMap { path, project in
            project.isExternal ? (path, project) : nil
        }.flatMap { projectPath, project in
            let targets = graph.targets[projectPath, default: [:]].values
            return targets.map { GraphTarget(path: projectPath, target: $0, project: project) }
        }
        return Set(targets)
    }

    public func allOrphanExternalTargets() -> Set<GraphTarget> {
        let graphDependenciesWithExternalDependencies = Set(
            targetsWithExternalDependencies()
                .map { GraphDependency.target(name: $0.target.name, path: $0.project.path) }
        )

        let allTargetExternalDependendedUponTargets = filterDependencies(from: graphDependenciesWithExternalDependencies)
            .compactMap { graphDependency -> GraphTarget? in
                if case let GraphDependency.target(name, path, _) = graphDependency,
                    let target = graph.targets[path]?[name],
                    let project = graph.projects[path]
                {
                    return GraphTarget(path: path, target: target, project: project)
                } else {
                    return nil
                }
            }
        let allExternalTargets = allExternalTargets()
        return allExternalTargets.subtracting(allTargetExternalDependendedUponTargets)
    }

    public func allUnusedDependencies() -> Set<TargetDependency> {
        var unusedDeps: Set<TargetDependency> = []
        for (_, deps) in graph.externalDependenciesGraph.externalDependencies {
            for dep in deps {
                switch dep {
                case let .framework(path, _, _):
                    if frameworks[path] == nil {
                        unusedDeps.insert(dep)
                    }
                case let .library(path, _, _, _):
                    if libraries[path] == nil {
                        unusedDeps.insert(dep)
                    }
                case let .xcframework(path, _, _):
                    if xcframeworks[path] == nil {
                        unusedDeps.insert(dep)
                    }
                case .local, .sdk, .target, .xctest, .external, .project, .bundle:
                    break
                @unknown default:
                    break
                }
            }
        }
        return unusedDeps
    }

    public func allSwiftPluginExecutables(path: AbsolutePath, name: String) -> Set<String> {
        func precompiledMacroDependencies(_ graphDependency: GraphDependency) -> Set<AbsolutePath> {
            Set(
                dependencies[graphDependency, default: Set()]
                    .lazy
                    .compactMap {
                        if case let GraphDependency.macro(path) = $0 {
                            return path
                        } else {
                            return nil
                        }
                    }
            )
        }

        let precompiledMacroPluginExecutables = filterDependencies(
            from: .target(name: name, path: path),
            test: { dependency in
                switch dependency {
                case .xcframework:
                    return !precompiledMacroDependencies(dependency).isEmpty
                case .macro:
                    return true
                case .bundle, .library, .framework, .sdk, .target:
                    return false
                }
            },
            skip: { dependency in
                switch dependency {
                case .macro:
                    return true
                case .bundle, .library, .framework, .sdk, .target, .xcframework:
                    return false
                }
            }
        )
        .flatMap { dependency in
            switch dependency {
            case .xcframework:
                return Array(precompiledMacroDependencies(dependency))
            case let .macro(path):
                return [path]
            case .bundle, .library, .framework, .sdk, .target:
                return []
            }
        }
        .map { "\($0.pathString)#\($0.basename.replacingOccurrences(of: ".macro", with: ""))" }

        let sourceMacroPluginExecutables = allSwiftMacroTargets(path: path, name: name)
            .flatMap { target in
                directSwiftMacroExecutables(path: target.project.path, name: target.target.name).map { (target, $0) }
            }
            .compactMap { _, dependencyReference in
                switch dependencyReference {
                case let .product(_, productName, _, _):
                    return "$BUILD_DIR/Debug$EFFECTIVE_PLATFORM_NAME/\(productName)#\(productName)"
                default:
                    return nil
                }
            }

        return Set(precompiledMacroPluginExecutables + sourceMacroPluginExecutables)
    }

    // MARK: - Internal

    /// The method collects the dependencies that are selected by the provided test closure.
    /// The skip closure allows skipping the traversing of a specific dependendency branch.
    /// - Parameters:
    ///   - from: Dependency from which the traverse is done.
    ///   - test: If the closure returns true, the dependency is included.
    ///   - skip: If the closure returns false, the traversing logic doesn't traverse the dependencies from that dependency.
    func filterDependencies(
        from rootDependency: GraphDependency,
        test: (GraphDependency) -> Bool = { _ in true },
        skip: (GraphDependency) -> Bool = { _ in false }
    ) -> Set<GraphDependency> {
        filterDependencies(from: [rootDependency], test: test, skip: skip)
    }

    /// The method collects the dependencies that are selected by the provided test closure.
    /// The skip closure allows skipping the traversing of a specific dependendency branch.
    /// - Parameters:
    ///   - from: Dependencies from which the traverse is done.
    ///   - test: If the closure returns true, the dependency is included.
    ///   - skip: If the closure returns false, the traversing logic doesn't traverse the dependencies from that dependency.
    func filterDependencies(
        from rootDependencies: Set<GraphDependency>,
        test: (GraphDependency) -> Bool = { _ in true },
        skip: (GraphDependency) -> Bool = { _ in false }
    ) -> Set<GraphDependency> {
        var stack = [GraphDependency]()

        stack.append(contentsOf: rootDependencies)

        var visited: Set<GraphDependency> = .init()
        var references = [GraphDependency]()

        while !stack.isEmpty {
            guard let node = stack.popLast() else {
                continue
            }

            if visited.contains(node) {
                continue
            }

            visited.insert(node)

            if !rootDependencies.contains(node), test(node) {
                references.append(node)
            }

            if !rootDependencies.contains(node), skip(node) {
                continue
            }

            for nodeDependency in graph.dependencies[node] ?? [] {
                if !visited.contains(nodeDependency) {
                    stack.append(nodeDependency)
                }
            }
        }
        return Set(references)
    }

    /// Recursively find platform filters within transitive dependencies
    /// - Parameters:
    ///   - rootDependency: dependency whose platform filters we need when depending on `transitiveDependency`
    ///   - transitiveDependency: target dependency
    /// - Returns: CombinationResult which represents a resolved condition or `.incompatible` based on traversing
    public func combinedCondition(
        to transitiveDependency: GraphDependency,
        from rootDependency: GraphDependency
    ) -> PlatformCondition.CombinationResult {
        if graph.dependencyConditions.isEmpty {
            return .condition(nil)
        }

        if !conditionMapCalculated {
            calculateCombinedConditionMap()
        }

        return conditionMap[rootDependency]?[transitiveDependency] ?? .condition(nil)
    }

    private func calculateCombinedConditionMap() {
        var result: [GraphDependency: [GraphDependency: PlatformCondition.CombinationResult]] = [:]

        func dfs(_ node: GraphDependency) {
            guard result[node] == nil else { return }

            for dep in graph.dependencies[node] ?? [] {
                dfs(dep)

                let currentCondition = graph.dependencyConditions[(node, dep)]

                // Capture the filters that could be applied to intermediate dependencies
                // A --> (.ios) B --> C : C should have the .ios filter applied due to B
                for (transitiveDep, transitiveCondition) in result[dep] ?? [:] {
                    let combinedCondition: PlatformCondition.CombinationResult
                    switch transitiveCondition {
                    case .incompatible:
                        combinedCondition = .incompatible
                    case let .condition(.some(condition)):
                        combinedCondition = condition.intersection(currentCondition)
                    case .condition:
                        combinedCondition = .condition(currentCondition)
                    }

                    // Union our filters because multiple paths could lead to the same dependency (e.g. AVFoundation)
                    //  A --> (.ios) B --> C
                    //  A --> (.macos) D --> C
                    // C should have `[.ios, .macos]` set for filters to satisfy both paths
                    let previousResult = result[node, default: [:]][transitiveDep] ?? .incompatible
                    let newResult = previousResult.combineWith(combinedCondition)

                    result[node, default: [:]][transitiveDep] = newResult
                }
            }

            for dep in graph.dependencies[node] ?? [] {
                result[node, default: [:]][dep] = .condition(graph.dependencyConditions[(node, dep)])
            }
        }

        for node in graph.dependencies.keys {
            dfs(node)
        }

        conditionMap = result
        conditionMapCalculated = true
    }

    public func externalTargetSupportedPlatforms() -> [GraphTarget: Set<Platform>] {
        let targetsWithExternalDependencies = targetsWithExternalDependencies()
        var platforms: [GraphTarget: Set<Platform>] = [:]

        func traverse(target: GraphTarget, parentPlatforms: Set<Platform>) {
            let dependencies = directTargetDependencies(path: target.path, name: target.target.name)

            for dependencyTargetReference in dependencies {
                var platformsToInsert: Set<Platform>?
                let dependencyTarget = dependencyTargetReference.graphTarget
                let inheritedPlatforms =
                    dependencyTarget.target.product == .macro
                        ? Set<Platform>([.macOS]) : parentPlatforms
                
                if let dependencyCondition = dependencyTargetReference.condition,
                    let platformIntersection = PlatformCondition.when(target.target.dependencyPlatformFilters)?
                        .intersection(dependencyCondition)
                {
                    switch platformIntersection {
                    case .incompatible:
                        break
                    case let .condition(condition):
                        if let condition {
                            let dependencyPlatforms = Set(
                                condition.platformFilters.map(\.platform)
                                    .filter { $0 != nil }
                                    .map { $0! }
                            ).intersection(inheritedPlatforms)
                            platformsToInsert = dependencyPlatforms
                        }
                    }
                } else {
                    platformsToInsert = inheritedPlatforms.intersection(
                        dependencyTarget.target.supportedPlatforms
                    )
                }

                if let platformsToInsert {
                    var existingPlatforms = platforms[dependencyTarget, default: Set()]
                    let continueTraversing = !platformsToInsert.isSubset(of: existingPlatforms)
                    existingPlatforms.formUnion(platformsToInsert)
                    platforms[dependencyTarget] = existingPlatforms

                    if continueTraversing {
                        traverse(target: dependencyTarget, parentPlatforms: platforms[dependencyTarget, default: Set()])
                    }
                }
            }
        }

        targetsWithExternalDependencies.forEach { traverse(target: $0, parentPlatforms: $0.target.supportedPlatforms) }
        return platforms
    }

    func allDependenciesSatisfy(from rootDependency: GraphDependency, meets: (GraphDependency) -> Bool) -> Bool {
        var allSatisfy = true
        _ = filterDependencies(
            from: rootDependency,
            test: { dependency in
                if !meets(dependency) {
                    allSatisfy = false
                }
                return true
            })
        return allSatisfy
    }

    func transitiveLinkableStaticDependencies(from dependency: GraphDependency) -> Set<GraphDependency> {
        filterDependencies(
            from: dependency,
            test: isDependencyStatic,
            skip: or(canDependencyLinkStaticProducts, isDependencyPrecompiledMacro)
        )
    }

    func transitiveStaticDependencies(from dependency: GraphDependency) -> Set<GraphDependency> {
        filterDependencies(
            from: dependency,
            test: isDependencyStatic,
            skip: isDependencyPrecompiledMacro
        )
    }

    func isDependencyPrecompiledMacro(_ dependency: GraphDependency) -> Bool {
        switch dependency {
        case .macro:
            return true
        case .bundle, .framework, .xcframework, .library, .sdk, .target:
            return false
        }
    }

    func isDependencyPrecompiledLibrary(dependency: GraphDependency) -> Bool {
        switch dependency {
        case .macro: return false
        case .xcframework: return true
        case .framework: return true
        case .library: return true
        case .bundle: return true
        case .target: return false
        case .sdk: return false
        }
    }

    func isDependencyPrecompiledFramework(dependency: GraphDependency) -> Bool {
        switch dependency {
        case .macro: return false
        case .xcframework: return true
        case .framework: return true
        case .library: return false
        case .bundle: return false
        case .target: return false
        case .sdk: return false
        }
    }

    func isXCFrameworkMerged(dependency: GraphDependency, expectedMergedBinaries: Set<String>) -> Bool {
        guard case let .xcframework(xcframework) = dependency,
            let binaryName = xcframework.infoPlist.libraries.first?.binaryName,
            expectedMergedBinaries.contains(binaryName)
        else {
            return false
        }
        if !xcframework.mergeable {
            fatalError("XCFramework \(binaryName) must be compiled with  -make_mergeable option enabled")
        }
        return xcframework.mergeable
    }

    func isDependencyDynamicNonMergeableTarget(dependency: GraphDependency) -> Bool {
        guard case let GraphDependency.target(name, path, _) = dependency,
            let target = target(path: path, name: name)
        else { return false }
        return !target.target.mergeable
    }

    func isDependencyStaticTarget(dependency: GraphDependency) -> Bool {
        guard case let GraphDependency.target(name, path, _) = dependency,
            let target = target(path: path, name: name)
        else { return false }
        return target.target.product.isStatic
    }

    func isDependencyStatic(dependency: GraphDependency) -> Bool {
        switch dependency {
        case .macro:
            return false
        case let .xcframework(xcframework):
            return xcframework.linking == .static
        case let .framework(_, _, _, _, linking, _, _),
            let .library(_, _, linking, _, _):
            return linking == .static
        case .bundle: return false
        case let .target(name, path, _):
            guard let target = target(path: path, name: name) else { return false }
            return target.target.product.isStatic
        case .sdk: return false
        }
    }

    func isDependencyDynamic(dependency: GraphDependency) -> Bool {
        switch dependency {
        case .macro:
            return false
        case let .xcframework(xcframework):
            return xcframework.linking == .dynamic
        case let .framework(_, _, _, _, linking, _, _),
            let .library(_, _, linking, _, _):
            return linking == .dynamic
        case .bundle: return false
        case let .target(name, path, _):
            guard let target = target(path: path, name: name) else { return false }
            return target.target.product.isDynamic
        case .sdk: return true
        }
    }

    func isDependencyLinkable(dependency: GraphDependency) -> Bool {
        switch dependency {
        case .macro, .bundle:
            return false
        case .xcframework, .framework, .library, .sdk:
            return true
        case let .target(name, path, _):
            guard let target = target(path: path, name: name) else { return false }
            return target.target.isLinkable()
        }
    }

    func isDependencyDynamicLibrary(dependency: GraphDependency) -> Bool {
        guard case let GraphDependency.target(name, path, _) = dependency,
            let target = target(path: path, name: name)
        else { return false }
        return target.target.product == .dynamicLibrary
    }

    func isDependencyFramework(dependency: GraphDependency) -> Bool {
        guard case let GraphDependency.target(name, path, _) = dependency,
            let target = target(path: path, name: name)
        else { return false }
        return target.target.product == .framework
    }

    func isDependencyDynamicTarget(dependency: GraphDependency) -> Bool {
        switch dependency {
        case .macro: return false
        case .xcframework: return false
        case .framework: return false
        case .library: return false
        case .bundle: return false
        case let .target(name, path, _):
            guard let target = target(path: path, name: name) else { return false }
            return target.target.product.isDynamic
        case .sdk: return false
        }
    }

    func canDependencyEmbedBinaries(dependency: GraphDependency) -> Bool {
        guard case let GraphDependency.target(name, path, _) = dependency,
            let target = target(path: path, name: name)
        else { return false }
        return canEmbedFrameworks(target: target.target)
    }

    func canDependencyEmbedBundles(dependency: GraphDependency) -> Bool {
        guard case let GraphDependency.target(name, path, _) = dependency,
              let target = target(path: path, name: name) else { return false }
        return canEmbedBundles(target: target.target)
    }

    func canDependencyLinkStaticProducts(dependency: GraphDependency) -> Bool {
        switch dependency {
        case let .target(name, path, _):
            guard let target = target(path: path, name: name) else { return false }
            return target.target.canLinkStaticProducts()
        case let .framework(_, _, _, _, linking, _, _):
            return linking == .dynamic
        case let .xcframework(xcframework):
            return xcframework.linking == .dynamic
        case let .library(_, _, linking, _, _):
            return linking == .dynamic
        default:
            return false
        }
    }

    func unitTestHost(path: AbsolutePath, name: String) -> GraphTarget? {
        directLocalTargetDependencies(path: path, name: name)
            .first(where: { $0.target.product.canHostTests() })?.graphTarget
    }

    func canEmbedFrameworks(target: Target) -> Bool {
        let validProducts: [Product] = [
            .app,
            .watch2App,
            .appClip,
            .unitTests,
            .uiTests,
            .watch2Extension,
            .systemExtension,
            .xpc,
        ]
        return validProducts.contains(target.product)
    }

    func canEmbedBundles(target: Target) -> Bool {
        let validProducts: [Product] = [
            .app,
            .appExtension,
            .watch2App,
            .appClip,
            .unitTests,
            .uiTests,
            .watch2Extension,
            .systemExtension,
            .xpc,
        ]
        return validProducts.contains(target.product)
    }

    // swiftlint:disable:next function_body_length
    func dependencyReference(
        to toDependency: GraphDependency,
        from fromDependency: GraphDependency
    ) -> GraphDependencyReference? {
        guard case let .condition(condition) = combinedCondition(to: toDependency, from: fromDependency) else {
            return nil
        }

        switch toDependency {
        case let .macro(path):
            return .macro(path: path)
        case let .framework(path, binaryPath, dsymPath, bcsymbolmapPaths, linking, architectures, status):
            return .framework(
                path: path,
                binaryPath: binaryPath,
                dsymPath: dsymPath,
                bcsymbolmapPaths: bcsymbolmapPaths,
                linking: linking,
                architectures: architectures,
                product: (linking == .static) ? .staticFramework : .framework,
                status: status,
                condition: condition
            )
        case let .library(path, _, linking, architectures, _):
            return .library(
                path: path,
                linking: linking,
                architectures: architectures,
                product: (linking == .static) ? .staticLibrary : .dynamicLibrary,
                condition: condition
            )
        case let .bundle(path):
            return .bundle(path: path, condition: condition)
        case let .sdk(_, path, status, source):
            return .sdk(
                path: path,
                status: status,
                source: source,
                condition: condition
            )
        case let .target(name, path, status):
            guard let target = target(path: path, name: name) else { return nil }
            return .product(
                target: target.target.name,
                productName: target.target.productNameWithExtension,
                status: status,
                condition: condition
            )
        case let .xcframework(xcframework):
            return .xcframework(
                path: xcframework.path,
                infoPlist: xcframework.infoPlist,
                primaryBinaryPath: xcframework.primaryBinaryPath,
                binaryPath: xcframework.primaryBinaryPath,
                status: xcframework.status,
                condition: condition
            )
        }
    }

    private func isDependencyResourceBundle(dependency: GraphDependency) -> Bool {
        switch dependency {
        case .bundle:
            return true
        case let .target(name: name, path: path, _):
            return target(path: path, name: name)?.target.product == .bundle
        default:
            return false
        }
    }

    private func allTargets(excludingExternalTargets: Bool) -> Set<GraphTarget> {
        Set(
            projects.flatMap { projectPath, project -> [GraphTarget] in
                if excludingExternalTargets, project.isExternal { return [] }

                let targets = graph.targets[projectPath, default: [:]]
                return targets.values.map { target in
                    GraphTarget(path: projectPath, target: target, project: project)
                }
            })
    }

    private func staticPrecompiledXCFrameworksDependencies(
        path: AbsolutePath,
        name: String
    ) -> [GraphDependencyReference] {
        let dependencies = filterDependencies(
            from: .target(name: name, path: path),
            test: { dependency in
                switch dependency {
                case let .xcframework(xcframework):
                    return xcframework.linking == .static
                case .framework, .library, .bundle, .target, .sdk, .macro:
                    return false
                }
            },
            skip: { $0.isDynamicPrecompiled || !$0.isPrecompiled || $0.isPrecompiledMacro }
        )
        return Set(dependencies)
            .compactMap { dependencyReference(to: $0, from: .target(name: name, path: path)) }
    }
}

// swiftlint:enable type_body_length
