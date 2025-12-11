import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

private enum Constants {
    static let xlinker = "-Xlinker"
    static let addAstPathFlag = "-add_ast_path"
    static let otherLdflags = "OTHER_LDFLAGS"

    static func makeAstPath(for module: String, productName: String, addSubdirectory: Bool) -> String {
        var result = "$(BUILT_PRODUCTS_DIR)/"
        if addSubdirectory {
            result += "\(module)/"
        }
        result += "\(productName).framework/"
        result += "Modules/\(productName).swiftmodule/$(NATIVE_ARCH_ACTUAL)-$(LLVM_TARGET_TRIPLE_VENDOR)-$(SHALLOW_BUNDLE_TRIPLE).swiftmodule"
        return result
    }

}

/// Runnable targets ast paths adder.
///
/// This mapper adds `-add_ast_path` and path to `.swiftmodule` file of static framework or static library
/// for each runnable graph's target direct dependency.
/// This helps to repair debugging caused by 'Couldn't realize Swift AST type of self' error.
/// https://developer.apple.com/videos/play/wwdc2022/110370/
public final class RunnableTargetsAstPathsAddingGraphMapper: GraphMapping {

    private let addAstPathsToLinker: Config.GenerationOptions.LinkerAstPaths
    private let modulesUseSubdirectory: Bool

    // MARK: - Initialization

    public init(addAstPathsToLinker: Config.GenerationOptions.LinkerAstPaths, modulesUseSubdirectory: Bool) {
        self.addAstPathsToLinker = addAstPathsToLinker
        self.modulesUseSubdirectory = modulesUseSubdirectory
    }

    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        guard addAstPathsToLinker.isEnabled else { return [] }

        let graphTraverser = GraphTraverser(graph: graph)

        func isForDebugging(target: Target) -> Bool {
            target.product.runnable || target.product.testsBundle
        }

        let pathsToTargets = graphTraverser.allInternalTargets()
            .filter { isForDebugging(target: $0.target) }
            .map { ($0.path, $0) }

        for (path, runnableTarget) in pathsToTargets {
            let targetDependencies = targetDependencies(
                graphTraverser: graphTraverser,
                path: runnableTarget.path,
                name: runnableTarget.target.name
            ).filter {
                shouldInclude(target: $0.target, from: sideTable)
            }

            let params = targetDependencies
                .flatMap {
                    [
                        Constants.xlinker,
                        Constants.addAstPathFlag,
                        Constants.xlinker,
                        Constants.makeAstPath(for: $0.target.name, productName: $0.target.productName, addSubdirectory: modulesUseSubdirectory)
                    ]
                }

            guard !params.isEmpty else { continue }

            let flags: SettingValue = .array(["$(inherited)"] + params)
            var modifiedTarget = runnableTarget.target
            modifiedTarget.settings?.baseDebug.merge([Constants.otherLdflags: flags]) { old, new in
                old.combine(with: new)
            }
            graph.targets[path]?[modifiedTarget.name] = modifiedTarget

            guard var modifiedProject = graph.projects[path] else { continue }

            for (index, target) in modifiedProject.targets.enumerated() where isForDebugging(target: target) {
                var projectTarget = target
                projectTarget.settings?.baseDebug.merge([Constants.otherLdflags: flags]) { old, new in
                    old.combine(with: new)
                }
                modifiedProject.targets[index] = projectTarget
            }
            graph.projects[path] = modifiedProject
        }

        return []
    }
    
    private func targetDependencies(graphTraverser: GraphTraverser, path: AbsolutePath, name: String) -> Set<GraphTarget> {
        return switch addAstPathsToLinker {
        case .disabled:
            []
        case .forAllDirectDependencies, .forFocusedTargetsOnly:
            Set(graphTraverser.directTargetDependencies(path: path, name: name).map { $0.graphTarget })
        case .forAllDependencies:
            graphTraverser.allTargetDependencies(path: path, name: name)
        }
    }

    private func shouldInclude(target: Target, from sideTable: GekoGraph.GraphSideTable) -> Bool {
        return switch addAstPathsToLinker {
        case .disabled:
            false
        case .forAllDirectDependencies, .forAllDependencies:
            // Take only static frameworks and libraries https://developer.apple.com/videos/play/wwdc2022/110370/?time=910
            target.product.isStatic
        case .forFocusedTargetsOnly:
            target.product.isStatic && sideTable.workspace.focusedTargets.contains(target.name)
        }
    }
}

private extension Config.GenerationOptions.LinkerAstPaths {
    var isEnabled: Bool {
        guard case .disabled = self else { return true }
        return false
    }
}
