import Foundation
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import struct ProjectDescription.FilePath
import GekoCore
import GekoDependencies
import GekoGraph
import GekoSupport

private extension NSRegularExpression {
    static let workspaceRegex = try! NSRegularExpression(pattern: #"^Workspace(\+[A-Za-z0-9_]+)?\.swift$"#)
}

public final class ImpactAnalysisGraphMapper {
    private var environment: Environmenting
    private var system: Systeming
    private var fileHandler: FileHandling
    private let globConverter: GlobConverter
    private var symlinks: [String: String]

    public init(
        environment: Environmenting = Environment.shared,
        system: Systeming = System.shared,
        fileHandler: FileHandling = FileHandler.shared,
        globConverter: GlobConverter = GlobConverter()
    ) {
        self.environment = environment
        self.system = system
        self.fileHandler = fileHandler
        self.globConverter = globConverter
        self.symlinks = environment.impactAnalysisSymlinksSupportEnabled ? SymlinksFinder().findSymlinks(in: fileHandler.currentPath.asURL) : [:]
    }
}

// MARK: - GraphMapping

extension ImpactAnalysisGraphMapper: GraphMapping {
    public func map(
        graph: inout Graph,
        sideTable: inout GraphSideTable
    ) async throws -> [SideEffectDescriptor] {
        guard let gsst = graph.workspace.generationOptions.generateSharedTestTarget else {
            return []
        }

        let installTo = gsst.installTo
        guard
            let projectPath = graph.projects
                .first(where: { kv in kv.value.name == installTo })?
                .key
        else {
            fatalError("This should not be possible")
        }

        let targetNames = graph.projects[projectPath]!.targets
            .filter {
                sideTable.workspace.projects[projectPath]?.targets[$0.name]?.flags
                    .contains(.sharedTestTarget) == true
            }
            .map(\.name)

        let graphTraverser = GraphTraverser(graph: graph)

        if targetNames.isEmpty {
            return []
        }

        let clock = SuspendingClock()
        let start = clock.now

        var changedFiles = try gitFiles(.changed)
        var deletedFiles = try gitFiles(.onlyDeleted)

        if environment.impactAnalysisSymlinksSupportEnabled {
            var changedFilesLinks: Set<String> = []
            for file in changedFiles {
                changedFilesLinks.formUnion(getAllLink(to: file))
            }
            changedFiles.formUnion(changedFilesLinks)
            
            var deletedFilesLinks: Set<String> = []
            for file in deletedFiles {
                deletedFilesLinks.formUnion(getAllLink(to: file))
            }
            deletedFiles.formUnion(deletedFilesLinks)
        }

        let affectedGekoFiles = affectedGekoFiles(changedFiles: changedFiles, deletedFiles: deletedFiles)
        let initiallyChangedTargets: Set<GraphDependency>
        
        if !affectedGekoFiles.isEmpty {
            initiallyChangedTargets = allTargets(graph: graph)
            
            logger.info("Geko manifests have been affected, so all targets will be affected.")
            logger.info("Affected Geko manifests: \(affectedGekoFiles)")
        } else {
            let changedLocalTargets = try changedLocalTargets(
                graph: graph,
                sideTable: &sideTable,
                changedFiles: changedFiles,
                deletedFiles: deletedFiles
            )
            let markedTargets = try markedAsChangedTargets(graph: graph)
            let (originalLockfile, newLockfile) = try lockfiles()
            let lockfileChanges = try lockfileChanges(
                graphTraverser: graphTraverser,
                originalLockfile: originalLockfile,
                newLockfile: newLockfile
            )
            initiallyChangedTargets = changedLocalTargets.union(lockfileChanges)
                .union(markedTargets)
            logger.info("Initially affected targets: \(initiallyChangedTargets)")

            logDump("Changed targets from source:\n", changedLocalTargets.map(\.description))
            logDump("Changed targets from lockfile:\n", lockfileChanges.map(\.description))
        }
        
        let allChangedTargets = allAffectedTargets(
            graphTraverser: graphTraverser,
            changedTargets: initiallyChangedTargets
        )
        logger.info("All affected targets: \(allChangedTargets)")

        logDump("All changed targets", allChangedTargets.map(\.description))

        let time = clock.now - start
        logger.info("Time took to apply impact analysis to graph: \(time)")

        applyChanges(
            to: &graph,
            sideTable: &sideTable,
            affectedTargets: Set(allChangedTargets),
            projectPath: projectPath,
            targetNames: targetNames
        )

        return []
    }
}

// MARK: - Private methods

extension ImpactAnalysisGraphMapper {
    // MARK: - Utils

    private var sourceRef: String {
        environment.impactSourceRef ?? "HEAD"
    }

    private var targetRef: String {
        guard let ref = environment.impactTargetRef else {
            fatalError("Environment variable \(Constants.EnvironmentVariables.impactAnalysisTargetRef) should be set")
        }
        return ref
    }

    private func logDump(_ header: String, _ object: some Any) {
        var string = "\(header)\n"
        dump(object, to: &string)
        logger.debug("\(string)")
    }

    // MARK: - Sources diff calculation
    
    private enum GitFilesOption {
        case onlyDeleted
        case changed
        
        var filter: String {
            switch self {
            case .onlyDeleted:
                "D"
            case .changed:
                "d"
            }
        }
    }

    private func gitFiles(_ option: GitFilesOption) throws -> Set<String> {
        let diff: String
        if environment.impactAnalysisDebug {
            diff = try system.capture(["git", "diff", "--name-only", "--no-renames", "--diff-filter=\(option.filter)"]).chomp()
        } else {
            diff = try system.capture(["git", "diff", "\(targetRef)...\(sourceRef)", "--name-only", "--no-renames", "--diff-filter=\(option.filter)"]).chomp()
        }
        
        if diff.isEmpty {
            return Set()
        }
        
        return Set(diff.components(separatedBy: "\n"))
    }

    private func markedAsChangedTargets(
        graph: borrowing Graph
    ) throws -> Set<GraphDependency> {
        let markedTargetNames = Set(environment.impactAnalysisChangedTargets)
        let markedProductNames = Set(environment.impactAnalysisChangedProducts)

        var result = Set<GraphDependency>()

        guard !markedTargetNames.isEmpty || !markedProductNames.isEmpty else {
            return result
        }

        for project in graph.projects.values {
            for target in project.targets {
                if markedTargetNames.contains(target.name) {
                    let changedTarget = GraphDependency.target(name: target.name, path: project.path)
                    result.insert(changedTarget)

                    continue
                }

                if markedProductNames.contains(target.productName) {
                    let changedTarget = GraphDependency.target(name: target.name, path: project.path)
                    result.insert(changedTarget)

                    continue
                }
            }
        }

        return result
    }

    private func changedLocalTargets(
        graph: borrowing Graph,
        sideTable: inout GraphSideTable,
        changedFiles: Set<String>,
        deletedFiles: borrowing Set<String>
    ) throws -> Set<GraphDependency> {
        var result = Set<GraphDependency>()

        let rootPath = graph.workspace.path
        let changedFilesAbsolutePaths = try changedFiles.map {
            let relativePath = try RelativePath(validating: $0)
            return rootPath.appending(relativePath)
        }

        for project in graph.projects.values {
            if isAffectedProjectManifest(changedFiles: changedFiles, deletedFiles: deletedFiles, project: project, rootPath: rootPath) {
                for target in project.targets {
                    let changedTarget = GraphDependency.target(name: target.name, path: project.path)
                    result.insert(changedTarget)
                }
                continue
            }

            targetLoop: for target in project.targets {
                for sourceFiles in target.sources {
                    for source in sourceFiles.paths {
                        let relativePath = try fileHandler.resolveSymlinks(source).relative(to: rootPath).pathString

                        if changedFiles.contains(relativePath) {
                            let changedTarget = GraphDependency.target(name: target.name, path: project.path)
                            result.insert(changedTarget)

                            continue targetLoop
                        }
                    }
                }

                for resource in target.resources {
                    switch resource {
                    case let .glob(path, _, _, _):
                        fatalError("globs in resources must be unwrapped before applying impact analysis: \(path)")
                    case let .file(path, _, _), let .folderReference(path, _, _):
                        let relativePath = try fileHandler.resolveSymlinks(path)
                            .relative(to: rootPath).pathString
                        
                        for changedFile in changedFiles {
                            if changedFile.hasPrefix(relativePath) {
                                let changedTarget = GraphDependency.target(name: target.name, path: project.path)
                                result.insert(changedTarget)

                                continue targetLoop
                            }
                        }
                    }
                }

                for file in target.additionalFiles {
                    switch file {
                    case let .glob(path):
                        fatalError("globs in resources must be unwrapped before applying impact analysis: \(path)")
                    case let .file(path), let .folderReference(path):
                        let relativePath = try fileHandler.resolveSymlinks(path)
                            .relative(to: rootPath).pathString

                        if changedFiles.contains(relativePath) {
                            let changedTarget = GraphDependency.target(name: target.name, path: project.path)
                            result.insert(changedTarget)

                            continue targetLoop
                        }
                    }
                }

                for buildableFolder in target.buildableFolders {
                    for changedFile in changedFilesAbsolutePaths {
                        if buildableFolder.path.isAncestor(of: changedFile)
                            && !buildableFolder.exceptions.contains(changedFile)
                        {
                            let changedTarget = GraphDependency.target(name: target.name, path: project.path)
                            result.insert(changedTarget)

                            continue targetLoop
                        }
                    }
                }
                
                guard !deletedFiles.isEmpty else {
                    continue targetLoop
                }
                
                if isAnyDeletedFileInTarget(sources: sideTable.sources(path: project.path, name: target.name), deletedFiles: deletedFiles) ||
                    isAnyDeletedFileInTarget(resources: sideTable.resources(path: project.path, name: target.name), deletedFiles: deletedFiles) ||
                    isAnyDeletedFileInTarget(additionalFiles: sideTable.additionalFiles(path: project.path, name: target.name), deletedFiles: deletedFiles) ||
                    isAnyDeletedFileInTarget(buildableFolders: target.buildableFolders, deletedFiles: deletedFiles, rootPath: rootPath)
                {
                    let changedTarget = GraphDependency.target(name: target.name, path: project.path)
                    result.insert(changedTarget)
                    
                    continue targetLoop
                }
            }
        }

        return result
    }
    
    // MARK: - Private
    
    private func getAllLink(to pathString: String) -> [String] {
        var output: [String] = []
        for (link, target) in symlinks {
            if pathString.contains(target + "/") || pathString == target {      
                output.append(pathString.replacing(target, with: link))
            }
        }
        return output
    }

    private func isAffectedProjectManifest(
        changedFiles: Set<String>,
        deletedFiles: Set<String>,
        project: Project,
        rootPath: AbsolutePath
    ) -> Bool {
        if let podspecPath = project.podspecPath {
            let podspecPath = podspecPath.relative(to: rootPath).pathString
            return changedFiles.contains(podspecPath)
        }
        
        let projectPath = project.path
            .relative(to: rootPath)
            .pathString
        
        let pattern: String
        if projectPath == "." {
            pattern = #"^Project(\+[A-Za-z0-9_]+)?\.swift$"#
        } else {
            pattern = "^\(projectPath)/" + #"Project(\+[A-Za-z0-9_]+)?\.swift$"#
        }
        
        guard let projectAndExtensionsRegex = try? NSRegularExpression(pattern: pattern) else {
            logger.warning("Error creating regex for pattern: \(pattern)")
            return false
        }
        
        let affectedProjectFiles = changedFiles.union(deletedFiles).filter {
            isMatch(string: $0, regex: projectAndExtensionsRegex)
        }
        return !affectedProjectFiles.isEmpty
    }
    
    private func affectedGekoFiles(
        changedFiles: Set<String>,
        deletedFiles: Set<String>
    ) -> Set<String> {
        let excludedFiles: Set<String> = [
            "Geko/Dependencies/Cocoapods.lock",
            "Geko/Dependencies.swift",
        ]
        
        let changedAndDeletedFiles = changedFiles.union(deletedFiles).subtracting(excludedFiles)

        let gekoWorkspaceFiles = changedAndDeletedFiles.filter { file in
            isMatch(string: file, regex: .workspaceRegex)
        }
        
        let gekoFolderFiles = changedAndDeletedFiles
            .filter({ $0.hasPrefix("Geko/") })
        
        return gekoFolderFiles.union(gekoWorkspaceFiles)
    }
    
    private func allTargets(graph: borrowing Graph) -> Set<GraphDependency> {
        var allTargets: Set<GraphDependency> = []
        
        for project in graph.projects.values {
            for target in project.targets {
                let target = GraphDependency.target(name: target.name, path: project.path)
                allTargets.insert(target)
            }
        }
        
        return allTargets
    }
    
    private func isAnyDeletedFileInTarget(
        sources: [SourceFiles],
        deletedFiles: Set<String>
    ) -> Bool {
        for source in sources {
            var matchedFiles: Set<String> = []
            
            for sourceFileGlob in source.paths {
                let pattern = globConverter.toRegex(glob: sourceFileGlob.pathString, extended: true, globstar: true)
                
                let matchedSources = deletedFiles.filter { deletedFile in
                    isMatch(path: deletedFile, pattern: pattern)
                }
                
                matchedFiles.formUnion(matchedSources)
            }
            
            for exclude in source.excluding {
                let regexStr = globConverter.toRegex(
                    glob: exclude.pathString,
                    extended: true,
                    globstar: true
                )
                
                let matchedExcluded = matchedFiles.filter {
                    isMatch(path: $0, pattern: regexStr)
                }
                
                matchedFiles.subtract(matchedExcluded)
            }
            
            if !matchedFiles.isEmpty {
                return true
            }
        }
        return false
    }
    
    private func isAnyDeletedFileInTarget(
        resources: [FilePath],
        deletedFiles: Set<String>
    ) -> Bool {
        for resource in resources {
            let pattern = globConverter.toRegex(glob: resource.pathString, extended: true, globstar: true, flags: "g")
            
            let matchedFiles = deletedFiles.filter { deletedFile in
                isMatch(path: deletedFile, pattern: pattern)
            }
            
            if !matchedFiles.isEmpty {
                return true
            }
        }
        return false
    }
    
    private func isAnyDeletedFileInTarget(
        additionalFiles: [FilePath],
        deletedFiles: Set<String>
    ) -> Bool {
        for additionalFile in additionalFiles {
            let pattern = globConverter.toRegex(glob: additionalFile.pathString, extended: true, globstar: true)
            
            let matchedFiles = deletedFiles.filter { deletedFile in
                isMatch(path: deletedFile, pattern: pattern)
            }
            
            if !matchedFiles.isEmpty {
                return true
            }
        }
        return false
    }
    
    private func isAnyDeletedFileInTarget(
        buildableFolders: [BuildableFolder],
        deletedFiles: Set<String>,
        rootPath: AbsolutePath
    ) -> Bool {
        guard let deletedFilesAbsolutePaths = try? deletedFiles.map({
            let relativePath = try RelativePath(validating: $0)
            return rootPath.appending(relativePath)
        }) else { return false }
        
        for buildableFolder in buildableFolders {
            for deletedFile in deletedFilesAbsolutePaths {
                if buildableFolder.path.isAncestor(of: deletedFile)
                    && !buildableFolder.exceptions.contains(deletedFile)
                {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func isMatch(path: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        return isMatch(string: path, regex: regex)
    }
    
    private func isMatch(string: String, regex: NSRegularExpression) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.firstMatch(in: string, range: range) != nil
    }

    // MARK: - Lockfiles diff calculation

    private func lockfiles() throws -> (original: CocoapodsLockfile, new: CocoapodsLockfile) {
        let originalLockfile: Data
        let originalLockfileContext: ParseYamlContext
        let newLockfile: Data
        let newLockfileContext: ParseYamlContext

        let lockfilePath = try RelativePath(validating: "Geko/Dependencies/Cocoapods.lock")
        if environment.impactAnalysisDebug {
            let rootDir = fileHandler.currentPath

            originalLockfile = try system.capture(["git", "show", "HEAD:\(lockfilePath.pathString)"]).chomp().data(using: .utf8)!
            originalLockfileContext = .git(path: lockfilePath, ref: "HEAD")

            let newLockfilePath = rootDir.appending(lockfilePath)
            newLockfile = try fileHandler.readFile(newLockfilePath)
            newLockfileContext = .file(path: newLockfilePath)
        } else {
            originalLockfile = try system.capture(["git", "show", "\(targetRef):\(lockfilePath.pathString)"]).chomp()
                .data(using: .utf8)!
            originalLockfileContext = .git(path: lockfilePath, ref: "HEAD")

            newLockfile = try system.capture(["git", "show", "\(sourceRef):\(lockfilePath.pathString)"]).chomp()
                .data(using: .utf8)!
            newLockfileContext = .git(path: lockfilePath, ref: "HEAD")
        }

        let originalLockfileYml = try CocoapodsLockfile.from(data: originalLockfile, context: originalLockfileContext)!
        let newLockfileYml = try CocoapodsLockfile.from(data: newLockfile, context: newLockfileContext)!

        return (originalLockfileYml, newLockfileYml)
    }

    private func lockfileChanges(
        graphTraverser: GraphTraverser,
        originalLockfile: CocoapodsLockfile,
        newLockfile: CocoapodsLockfile
    ) throws -> Set<GraphDependency> {
        var changedDependencies = Set<String>()

        func compare(_ origLockfile: CocoapodsLockfile, _ newLockfile: CocoapodsLockfile) {
            for (source, origSourceData) in origLockfile.podsBySource {
                guard let newSourceData = newLockfile.podsBySource[source] else {
                    changedDependencies.formUnion(origSourceData.pods.keys)
                    continue
                }

                if origSourceData.ref != newSourceData.ref {
                    changedDependencies.formUnion(origSourceData.pods.keys)
                    changedDependencies.formUnion(newSourceData.pods.keys)
                    continue
                }

                for (pod, oldPodData) in origSourceData.pods {
                    let newPodData = newSourceData.pods[pod]

                    if oldPodData != newPodData {
                        changedDependencies.insert(pod)
                    }
                }
            }
        }

        compare(originalLockfile, newLockfile)
        compare(newLockfile, originalLockfile)

        var result = Set<GraphDependency>()

        let externalGraph = graphTraverser.externalDependenciesGraph
        for dependency in changedDependencies {
            guard let dependencies = externalGraph.externalDependencies[dependency] else {
                continue  // dependency was deleted
            }

            for dep in dependencies {
                switch dep {
                case let .bundle(path, _):
                    result.insert(GraphDependency.bundle(path: path))
                case let .framework(path, _, _):
                    guard let graphDependency = graphTraverser.frameworks[path] else {
                        // The dependency has not been added to any target. Skip
                        continue
                    }
                    result.insert(graphDependency)
                case let .library(path, _, _, _):
                    guard let graphDependency = graphTraverser.libraries[path] else {
                        // The dependency has not been added to any target. Skip
                        continue
                    }
                    result.insert(graphDependency)
                case let .project(target, path, _, _):
                    result.insert(GraphDependency.target(name: target, path: path))
                case let .xcframework(path, _, _):
                    guard let graphDependency = graphTraverser.xcframeworks[path] else {
                        // The dependency has not been added to any target. Skip
                        continue
                    }
                    result.insert(graphDependency)
                case .local, .sdk, .target, .xctest, .external:
                    break  // not applicable
                }
            }
        }

        return result
    }

    // MARK: - Impact analysis

    private func allAffectedTargets(
        graphTraverser: GraphTraverser,
        changedTargets: Set<GraphDependency>
    ) -> [GraphDependency] {
        let dependencies = graphTraverser.dependencies
        var cachedResult: [GraphDependency: Bool] = [:]
        for changedTarget in changedTargets {
            cachedResult[changedTarget] = true
        }

        func dfs(_ dependency: GraphDependency) -> Bool {
            if let result = cachedResult[dependency] {
                return result
            }

            guard let children = dependencies[dependency] else {
                cachedResult[dependency] = false
                return false
            }

            if children.intersection(changedTargets).count > 0 {
                cachedResult[dependency] = true
                return true
            }

            var res = false
            for child in children {
                res = res || dfs(child)
            }
            cachedResult[dependency] = res
            return res
        }

        for dependency in dependencies.keys {
            _ = dfs(dependency)
        }

        return cachedResult.filter(\.value).map(\.key)
    }

    // MARK: Graph manipulation

    private func applyChanges(
        to graph: inout Graph,
        sideTable: inout GraphSideTable,
        affectedTargets: consuming Set<GraphDependency>,
        projectPath: AbsolutePath,
        targetNames: [String]
    ) {
        var targets: [String: Target] = [:]
        for t in graph.projects[projectPath]!.targets {
            targets[t.name] = t
        }

        for targetName in targetNames {
            let dependency = GraphDependency.target(name: targetName, path: projectPath)

            logDump("dependencies of \(targetName) before\n", graph.dependencies[dependency]?.map(\.description) ?? [])

            graph.dependencies[dependency]?.mutate { set in
                for member in set {
                    guard
                        !affectedTargets.contains(member),
                        case let .target(name, path, _) = member,
                        let flags = sideTable.workspace.projects[path]?.targets[name]?.flags,
                        flags.contains(.sharedTestTargetGeneratedFramework)
                    else {
                        continue
                    }

                    set.remove(member)
                    graph.targets[path]?[name]?.prune = true
                }
            }

            logDump("dependencies of \(targetName) after\n", graph.dependencies[dependency]?.map(\.description) ?? [])
        }

        graph.projects[projectPath]?.targets = Array(targets.values)
    }
}

// MARK: - Utils

extension Set {
    fileprivate mutating func mutate(_ closure: (inout Self) -> Void) {
        closure(&self)
    }
}
