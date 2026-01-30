import Foundation
import GekoKit

protocol IWorkspaceMapper {
    func focusedTargetsResolverGraphMapper(_ workspace: Workspace) throws -> Workspace
    func focusedTargetsExpanderGraphMapper(_ workspace: Workspace) throws -> Workspace
}

final class WorkspaceMapper: IWorkspaceMapper {
    
    // MARK: - Attributes
    private let configsProvider: IConfigsProvider
    private let projectsProvider: IProjectsProvider
    
    private var config: Configuration {
        if let project = projectsProvider.selectedProject(), let config = configsProvider.selectedConfig(for: project) {
            return config
        } else {
            return Configuration(name: "Default", profile: "default", deploymentTarget: "sim", options: [:], focusModules: [])
        }
    }
    
    private var regexs: Set<String> {
        Set(config.userRegex)
    }
    
    private var modules: Set<String> {
        Set(config.focusModules)
    }
    
    private var focusTests: Bool {
        config.options["--focus-tests"] ?? false
    }
    
    private var dependenciesOnly: Bool {
        config.options["--dependencies-only"] ?? false
    }
    
    private var focusDirectDependencies: Bool {
        config.options["--focus-direct-dependencies"] ?? false
    }
    
    private var unsafe: Bool {
        config.options["--unsafe"] ?? false
    }
    
    private var schemeName: String? {
        config.scheme
    }
    
    private var cacheEnabled: Bool {
        config.options["-cache"] ?? false
    }
    
    init(configsProvider: IConfigsProvider, projectsProvider: IProjectsProvider) {
        self.configsProvider = configsProvider
        self.projectsProvider = projectsProvider
    }
    
    func focusedTargetsResolverGraphMapper(_ workspace: Workspace) throws -> Workspace {
        var focusedTargets: Set<String> = ["GekoCache"]
        let sources: Set<String> = regexs.union(modules)
        guard !sources.isEmpty else {
            return workspace
        }
        let allTargets = workspace.allTargets(excludingExternalTargets: false)
        
        /// append sources
        let regexes = try sources.map { try Regex($0) }
        var filteredTargetsNames: Set<String> = []
        for target in allTargets {
            for regex in regexes {
                if try regex.wholeMatch(in: target.name) != nil {
                    filteredTargetsNames.insert(target.name)
                    if allTargets.contains(where: { "\(target.name)Resources" == $0.name }) {
                        filteredTargetsNames.insert("\(target.name)Resources")
                    }
                }
            }
        }
        focusedTargets.formUnion(filteredTargetsNames)
        
        if focusTests {
            var testTargetNames: Set<String> = []
            for target in focusedTargets {
                let testTargets = allTargets
                    .filter { $0.name.contains(target) }
                    .filter { !$0.product.runnable }
                    .filter { $0.product.testsBundle || $0.product.canHostTests }
                testTargets.forEach {
                    testTargetNames.insert($0.name)
                }
            }
            focusedTargets.formUnion(testTargetNames)
        }
        
        if let schemeName = schemeName, let scheme = workspace.schemes().first(where: { $0.name == schemeName }) {
            let schemeTargets = scheme.buildAction?.targets.map { $0.targetName } ?? []
            focusedTargets.formUnion(schemeTargets)
        }
        
        workspace.focusedTargets = Array(focusedTargets)
        return workspace
    }
    
    func focusedTargetsExpanderGraphMapper(_ workspace: Workspace) throws -> Workspace {
        var focusedTargets = workspace.focusedTargets
        guard !focusedTargets.isEmpty else {
            return workspace
        }
        let allTargets = workspace.allTargets(excludingExternalTargets: false)
        let targetsDict = Dictionary(uniqueKeysWithValues: allTargets.map { ($0.name, $0) })
        let allInternalTargets = workspace.allTargets(excludingExternalTargets: true)

        if dependenciesOnly {
            focusedTargets = allInternalTargets.map { $0.name }
        } else {
            if focusDirectDependencies {
                let nonRunnableSourceTargets = allInternalTargets
                    .filter { focusedTargets.contains($0.name) }
                    .filter { !$0.product.runnable }
                for target in nonRunnableSourceTargets {
                    focusedTargets.append(contentsOf: target.dependencies.map { $0.name })
                }
            }
            
            if !unsafe {
                var dependencyTargets: [String] = []
                for target in allInternalTargets {
                    let dependencies = target.dependencies.map { $0.name }
                    for focusedTarget in focusedTargets {
                        if dependencies.contains(focusedTarget) {
                            dependencyTargets.append(target.name)
                        }
                    }
                }
                focusedTargets.append(contentsOf: dependencyTargets)
            }
            
            let nonReplaceableTargets = allTargets
                .filter { focusedTargets.contains($0.name) }
                .filter { $0.product == .bundle }
                .map { $0.name }
            focusedTargets.append(contentsOf: nonReplaceableTargets)
            
            let nonReplaceableTargetDependencies = allTargets
                .flatMap { $0.dependencies }
                .filter { targetsDict[$0.name]?.product == .bundle }
                .map { $0.name }
            focusedTargets.append(contentsOf: nonReplaceableTargetDependencies)
        }
        
        workspace.focusedTargets = Array(focusedTargets)
        return workspace
    }
}
