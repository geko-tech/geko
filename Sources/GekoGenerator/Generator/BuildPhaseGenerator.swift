import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription
import XcodeProj

enum BuildPhaseGenerationError: FatalError, Equatable {
    case missingFileReference(AbsolutePath, String)
    case invalidHeaderMappingDir(mappingDirPath: AbsolutePath, headersDirPath: AbsolutePath)

    var description: String {
        switch self {
        case let .missingFileReference(path, targetName):
            return "Trying to add a file at path \(path.pathString) to a build phase that hasn't been added to the project. \(targetName)"
        case let .invalidHeaderMappingDir(mappingDirPath, headersDirPath):
            return "Mapping dir \(mappingDirPath) must be an ancestor of headers dir \(headersDirPath)"
        }
    }

    var type: ErrorType {
        switch self {
        case .missingFileReference:
            return .bug
        case .invalidHeaderMappingDir:
            return .abort
        }
    }
}

protocol BuildPhaseGenerating: AnyObject {
    func generateBuildPhases(
        path: AbsolutePath,
        target: Target,
        graphTraverser: GraphTraversing,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws

    /// Generates target actions
    ///
    /// - Parameters:
    ///   - scripts: Scripts to be generated as script build phases.
    ///   - pbxTarget: PBXTarget from the Xcode project.
    ///   - pbxproj: PBXProj instance.
    ///   - sourceRootPath: Path to the directory that will contain the generated project.
    /// - Throws: An error if the script phase can't be generated.
    func generateScripts(
        _ scripts: [TargetScript],
        pbxTarget: PBXTarget,
        pbxproj: PBXProj,
        sourceRootPath: AbsolutePath
    ) throws
}

// swiftlint:disable:next type_body_length
final class BuildPhaseGenerator: BuildPhaseGenerating {
    // MARK: - Attributes

    // swiftlint:disable:next function_body_length
    func generateBuildPhases(
        path: AbsolutePath,
        target: Target,
        graphTraverser: GraphTraversing,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        if target.shouldIncludeHeadersBuildPhase, let headers = target.headers {
            try generateHeadersBuildPhase(
                headers: headers,
                pbxTarget: pbxTarget,
                fileElements: fileElements,
                pbxproj: pbxproj
            )
        }

        if target.supportsSources {
            try generateSourcesBuildPhase(
                files: target.sources,
                coreDataModels: target.coreDataModels,
                target: target,
                pbxTarget: pbxTarget,
                fileElements: fileElements,
                pbxproj: pbxproj
            )
        }

        try generateResourcesBuildPhase(
            path: path,
            target: target,
            graphTraverser: graphTraverser,
            pbxTarget: pbxTarget,
            fileElements: fileElements,
            pbxproj: pbxproj
        )

        try generateCopyFilesBuildPhases(
            target: target,
            pbxTarget: pbxTarget,
            fileElements: fileElements,
            pbxproj: pbxproj
        )

        try generateAppExtensionsBuildPhase(
            path: path,
            target: target,
            graphTraverser: graphTraverser,
            pbxTarget: pbxTarget,
            fileElements: fileElements,
            pbxproj: pbxproj
        )

        try generateExtensionKitExtensionsBuildPhase(
            path: path,
            target: target,
            graphTraverser: graphTraverser,
            pbxTarget: pbxTarget,
            fileElements: fileElements,
            pbxproj: pbxproj
        )

        if target.canEmbedWatchApplications() {
            try generateEmbedWatchBuildPhase(
                path: path,
                target: target,
                graphTraverser: graphTraverser,
                pbxTarget: pbxTarget,
                fileElements: fileElements,
                pbxproj: pbxproj
            )
        }

        try generateEmbedXPCServicesBuildPhase(
            path: path,
            target: target,
            graphTraverser: graphTraverser,
            pbxTarget: pbxTarget,
            fileElements: fileElements,
            pbxproj: pbxproj
        )

        if target.canEmbedSystemExtensions() {
            try generateEmbedSystemExtensionBuildPhase(
                path: path,
                target: target,
                graphTraverser: graphTraverser,
                pbxTarget: pbxTarget,
                fileElements: fileElements,
                pbxproj: pbxproj
            )
        }

        try generateEmbedAppClipsBuildPhase(
            path: path,
            target: target,
            graphTraverser: graphTraverser,
            pbxTarget: pbxTarget,
            fileElements: fileElements,
            pbxproj: pbxproj
        )
    }

    func generateScripts(
        _ scripts: [TargetScript],
        pbxTarget: PBXTarget,
        pbxproj: PBXProj,
        sourceRootPath: AbsolutePath
    ) throws {
        for script in scripts {
            let buildPhase = try PBXShellScriptBuildPhase(
                files: [],
                name: script.name,
                inputPaths: script.inputPaths.files
                    .map {
                        $0.isAbsolute ? $0.relative(to: sourceRootPath).pathString : $0.pathString
                    },
                outputPaths: script.outputPaths.files
                    .map {
                        $0.isAbsolute ? $0.relative(to: sourceRootPath).pathString : $0.pathString
                    },
                inputFileListPaths: script.inputFileListPaths.map { $0.relative(to: sourceRootPath).pathString },

                outputFileListPaths: script.outputFileListPaths.map { $0.relative(to: sourceRootPath).pathString },

                shellPath: script.shellPath,
                shellScript: script.shellScript(sourceRootPath: sourceRootPath),
                runOnlyForDeploymentPostprocessing: script.runForInstallBuildsOnly,
                showEnvVarsInLog: script.showEnvVarsInLog,
                dependencyFile: script.dependencyFile?.relative(to: sourceRootPath).pathString
            )
            if let basedOnDependencyAnalysis = script.basedOnDependencyAnalysis {
                // Force the script to run in all incremental builds, if we
                // are NOT running it based on dependency analysis. Otherwise
                // leave it at the default value.
                buildPhase.alwaysOutOfDate = !basedOnDependencyAnalysis
            }

            pbxproj.add(object: buildPhase)
            pbxTarget.buildPhases.append(buildPhase)
        }
    }

    // swiftlint:disable:next function_body_length
    func generateSourcesBuildPhase(
        files: [SourceFiles],
        coreDataModels: [CoreDataModel],
        target: Target,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        let sourcesBuildPhase = PBXSourcesBuildPhase()
        pbxproj.add(object: sourcesBuildPhase)
        pbxTarget.buildPhases.append(sourcesBuildPhase)

        var buildFilesCache = Set<AbsolutePath>()
        var sourceFilesWithAttributes: [
            AbsolutePath: (
                compilerFlags: String?,
                codeGen: FileCodeGen?,
                compilationCondition: PlatformCondition?
            )?
        ] = [:]

        for sourceFiles in files {
            let hasNoAdditionalAttributes = sourceFiles.compilerFlags == nil && sourceFiles.codeGen == nil && sourceFiles.compilationCondition == nil
            for source in sourceFiles.paths {
                if hasNoAdditionalAttributes {
                    let emptyAttributes: (compilerFlags: String?, codeGen: FileCodeGen?, compilationCondition: PlatformCondition?)? = nil
                    if !sourceFilesWithAttributes.keys.contains(source) {
                        sourceFilesWithAttributes[source] = emptyAttributes
                    }
                } else {
                    var additionalAttributes = (sourceFiles.compilerFlags, sourceFiles.codeGen, sourceFiles.compilationCondition)

                    if let existed = sourceFilesWithAttributes[source] {
                        let mergedCompilerFlags = [existed?.compilerFlags, sourceFiles.compilerFlags]
                            .compactMap { $0 }
                            .joined(separator: " ")

                        additionalAttributes.0 = mergedCompilerFlags.isEmpty ? nil : mergedCompilerFlags
                        
                        if let unwrappedCondition = existed?.compilationCondition {
                            let merged = unwrappedCondition.platformFilters.union(sourceFiles.compilationCondition?.platformFilters ?? [])
                            additionalAttributes.2 = .when(merged)
                        }

                        sourceFilesWithAttributes[source] = additionalAttributes
                    } else {
                        sourceFilesWithAttributes[source] = additionalAttributes
                    }
                }
            }
        }

        var pbxBuildFiles = [PBXBuildFile]()
        for buildFile in sourceFilesWithAttributes.keys.sorted(by: { $0.basename < $1.basename }) {
            let buildFilePath = buildFile
            let isLocalized = buildFilePath.pathString.contains(".lproj/")
            let element: (element: PBXFileElement, path: AbsolutePath)
            if !isLocalized {
                guard let fileReference = fileElements.file(path: buildFile) else {
                    throw BuildPhaseGenerationError.missingFileReference(buildFile, target.name)
                }
                element = (fileReference, buildFilePath)
            } else {
                let name = buildFilePath.basename
                let path = buildFilePath.parentDirectory.parentDirectory.appending(component: name)
                guard let group = fileElements.group(path: path) else {
                    throw BuildPhaseGenerationError.missingFileReference(buildFilePath, target.name)
                }
                element = (group, path)
            }

            let (compilerFlags, codegen, compilationCondition) = (sourceFilesWithAttributes[buildFile] ?? nil) ?? (nil, nil, nil)

            var settings: [String: BuildFileSetting] = [:]
            if let compilerFlags {
                settings["COMPILER_FLAGS"] = .string(compilerFlags)
            }

            /// Source file ATTRIBUTES
            /// example: `settings = {ATTRIBUTES = (codegen, )`}
            if let codegen {
                settings["ATTRIBUTES"] = .array([codegen.rawValue])
            }

            if buildFilesCache.contains(element.path) == false {
                let pbxBuildFile = PBXBuildFile(file: element.element, settings: settings.isEmpty ? nil : settings)
                pbxBuildFile.applyCondition(compilationCondition, applicableTo: target)
                pbxBuildFiles.append(pbxBuildFile)
                buildFilesCache.insert(element.path)
            }
        }

        let coreDataModels = generateCoreDataModels(
            coreDataModels: coreDataModels,
            fileElements: fileElements,
            pbxproj: pbxproj
        )
        pbxBuildFiles.append(contentsOf: coreDataModels)
        pbxBuildFiles.forEach { pbxproj.add(object: $0) }
        sourcesBuildPhase.files = pbxBuildFiles
    }
    
    enum HeaderType: Hashable {
        case `public`
        case `private`
        case project
        
        var accessLevel: String? {
            switch self {
            case .public:
                return "public"
            case .private:
                return "private"
            case .project:
                return nil
            }
        }
    }
    
    struct TypedHeader: Hashable {
        let path: AbsolutePath
        let type: HeaderType
        let mappingsDir: AbsolutePath?
    }

    func generateHeadersBuildPhase(
        headers: HeadersList,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        guard !headers.list.isEmpty else { return }
        
        let headersBuildPhase = PBXHeadersBuildPhase()
        pbxproj.add(object: headersBuildPhase)
        pbxTarget.buildPhases.append(headersBuildPhase)

        let addHeader: (AbsolutePath, String?, PlatformCondition?) throws -> PBXBuildFile = { path, accessLevel, platformCondition in
            guard let fileReference = fileElements.file(path: path) else {
                throw BuildPhaseGenerationError.missingFileReference(path, pbxTarget.name)
            }
            let settings: [String: BuildFileSetting]? = accessLevel.map {
                ["ATTRIBUTES": .array([$0.capitalized])]
            }
            let file = PBXBuildFile(file: fileReference, settings: settings)
            file.applyPlatformFilters(platformCondition?.platformFilters)
            return file
        }
        var pbxBuildFiles: [PBXBuildFile] = []
        var typedHeadersWithCondition = [TypedHeader: PlatformCondition?]()
        
        for header in headers.list {
            let entries: [(HeaderType, [AbsolutePath])] = [
                (.public, header.public?.files ?? []),
                (.private, header.private?.files ?? []),
                (.project, header.project?.files ?? [])
            ]
            
            for (type, paths) in entries {
                for path in paths {
                    let key = TypedHeader(path: path, type: type, mappingsDir: header.mappingsDir)
                    if let existed = typedHeadersWithCondition[key] {
                        if let unwrappedCondition = existed {
                            let merged = unwrappedCondition.platformFilters.union(header.compilationCondition?.platformFilters ?? [])
                            typedHeadersWithCondition[key] = .when(merged)
                        } else {
                            typedHeadersWithCondition[key] = header.compilationCondition
                        }
                    } else {
                        typedHeadersWithCondition[key] = header.compilationCondition
                    }
                }
            }
        }
        
        try typedHeadersWithCondition.keys.sorted { $0.path < $1.path }.forEach { header in
            let condition = typedHeadersWithCondition[header] ?? nil
            // If the headers use mappingDir, then we should place them in the project access level.
            let headerType = header.mappingsDir == nil ? header.type : .project
            pbxBuildFiles.append(try addHeader(header.path, headerType.accessLevel, condition))
        }

        pbxBuildFiles.forEach { pbxproj.add(object: $0) }
        headersBuildPhase.files = pbxBuildFiles
        
        // For each mappingDir, we need to create copy files build phase
        // and copy the headers there according to their directories and access level.
        let mappingDirsHeaders = typedHeadersWithCondition.reduce(into: [AbsolutePath: [TypedHeader: PlatformCondition?]]()) { acc, value in
            guard let mappingDir = value.key.mappingsDir else { return }
            acc[mappingDir, default: [:]][value.key] = value.value
        }
        
        try mappingDirsHeaders.forEach { (mappingDir, headers) in
            try generateCopyHeadersBuildPhases(
                headers: headers,
                mappingsDir: mappingDir,
                pbxTarget: pbxTarget,
                fileElements: fileElements,
                pbxproj: pbxproj
            )
        }
    }

    func generateCopyHeadersBuildPhases(
        headers: [TypedHeader: PlatformCondition?],
        mappingsDir: AbsolutePath,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        func generatePhases(for headers: [AbsolutePath: PlatformCondition?], public: Bool) throws {
            var headersByDir: [AbsolutePath: [AbsolutePath: PlatformCondition?]] = [:]
            for header in headers.keys.sorted() {
                headersByDir[header.parentDirectory, default: [:]][header] = headers[header]
            }
            for dir in headersByDir.keys.sorted() {
                guard mappingsDir.isAncestorOfOrEqual(to: dir) else {
                    throw BuildPhaseGenerationError.invalidHeaderMappingDir(
                        mappingDirPath: mappingsDir,
                        headersDirPath: dir
                    )
                }
                let headersPath = dir.relative(to: mappingsDir)

                try generateCopyHeadersBuildPhase(
                    headers: headersByDir[dir]!,
                    public: `public`,
                    headersPath: headersPath,
                    pbxTarget: pbxTarget,
                    fileElements: fileElements,
                    pbxproj: pbxproj
                )
            }
        }

        let publicHeaders = headers.filter { $0.key.type == .public }.reduce(into: [AbsolutePath: PlatformCondition?]()) { acc, header in
            acc[header.key.path] = header.value
        }
        let privateHeaders = headers.filter { $0.key.type == .private }.reduce(into: [AbsolutePath: PlatformCondition?]()) { acc, header in
            acc[header.key.path] = header.value
        }
        
        try generatePhases(for: publicHeaders, public: true)
        try generatePhases(for: privateHeaders, public: false)
    }

    func generateCopyHeadersBuildPhase(
        headers: [AbsolutePath: PlatformCondition?],
        // private if false
        public: Bool,
        headersPath: RelativePath,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        let dst: String = `public` ? "$(PUBLIC_HEADERS_FOLDER_PATH)" : "$(PRIVATE_HEADERS_FOLDER_PATH)"
        let copyFilesPhase = PBXCopyFilesBuildPhase(
            dstPath: "\(dst)/\(headersPath.pathString)",
            dstSubfolderSpec: CopyFilesAction.Destination.productsDirectory.toXcodeprojSubFolder,
            name: "Copy \(headersPath.pathString) \(`public` ? "Public" : "Private") Headers"
        )

        pbxproj.add(object: copyFilesPhase)
        pbxTarget.buildPhases.append(copyFilesPhase)

        var buildFilesCache = Set<AbsolutePath>()
        var pbxBuildFiles = [PBXBuildFile]()
        for filePath in headers.keys.sorted() {
            guard let fileReference = fileElements.file(path: filePath) else {
                throw BuildPhaseGenerationError.missingFileReference(filePath, pbxTarget.name)
            }

            if buildFilesCache.contains(filePath) == false {
                let pbxBuildFile = PBXBuildFile(file: fileReference)
                pbxBuildFile.applyPlatformFilters(headers[filePath]??.platformFilters)
                pbxBuildFiles.append(pbxBuildFile)
                buildFilesCache.insert(filePath)
            }
        }
        pbxBuildFiles.forEach { pbxproj.add(object: $0) }
        copyFilesPhase.files = pbxBuildFiles
    }

    func generateResourcesBuildPhase(
        path: AbsolutePath,
        target: Target,
        graphTraverser: GraphTraversing,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        var pbxBuildFiles = [PBXBuildFile]()

        pbxBuildFiles.append(
            contentsOf: try generateResourcesBuildFile(
                target: target,
                files: target.resources,
                fileElements: fileElements
            )
        )

        try pbxBuildFiles.append(
            contentsOf: generateResourceBundle(
                path: path,
                target: target,
                graphTraverser: graphTraverser,
                fileElements: fileElements
            )
        )

        if !target.supportsSources {
            // CoreData models are typically added to the sources build phase
            // and Xcode automatically bundles the models.
            // For static libraries / frameworks however, they don't support resources,
            // the models could be bundled in a stand alone `.bundle`
            // as resources.
            //
            // e.g.
            // MyStaticFramework (.staticFramework) -> Includes CoreData models as sources
            // MyStaticFrameworkResources (.bundle) -> Includes CoreData models as resources
            //
            // - Note: Technically, CoreData models can be added a sources build phase in a `.bundle`
            // but that will result in the `.bundle` having an executable, which is not valid on iOS.
            pbxBuildFiles.append(
                contentsOf: generateCoreDataModels(
                    coreDataModels: target.coreDataModels,
                    fileElements: fileElements,
                    pbxproj: pbxproj
                )
            )
        }

        guard !pbxBuildFiles.isEmpty else { return }

        let resourcesBuildPhase = PBXResourcesBuildPhase()
        pbxproj.add(object: resourcesBuildPhase)
        pbxTarget.buildPhases.append(resourcesBuildPhase)

        pbxBuildFiles.forEach { pbxproj.add(object: $0) }
        resourcesBuildPhase.files = pbxBuildFiles
    }

    func generateCopyFilesBuildPhases(
        target: Target,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        for action in target.copyFiles {
            let copyFilesPhase = PBXCopyFilesBuildPhase(
                dstPath: action.subpath,
                dstSubfolderSpec: action.destination.toXcodeprojSubFolder,
                name: action.name
            )

            pbxproj.add(object: copyFilesPhase)
            pbxTarget.buildPhases.append(copyFilesPhase)

            var buildFilesCache = Set<AbsolutePath>()
            let filePaths = action.files.map(\.path).sorted()

            var pbxBuildFiles = [PBXBuildFile]()
            for filePath in filePaths {
                guard let fileReference = fileElements.file(path: filePath) else {
                    throw BuildPhaseGenerationError.missingFileReference(filePath, pbxTarget.name)
                }

                if buildFilesCache.contains(filePath) == false {
                    let pbxBuildFile = PBXBuildFile(file: fileReference)
                    pbxBuildFiles.append(pbxBuildFile)
                    buildFilesCache.insert(filePath)
                }
            }
            pbxBuildFiles.forEach { pbxproj.add(object: $0) }
            copyFilesPhase.files = pbxBuildFiles
        }
    }

    private func generateResourcesBuildFile(
        target: Target,
        files: [ResourceFileElement],
        fileElements: ProjectFileElements
    ) throws -> [PBXBuildFile] {
        var buildFilesCache = Set<AbsolutePath>()
        var pbxBuildFiles = [PBXBuildFile]()
        let ignoredVariantGroupExtensions = [".intentdefinition"]

        for resource in files.sorted(by: { $0.path < $1.path }) {
            let buildFilePath = resource.path

            let pathString = buildFilePath.pathString
            let isLocalized = pathString.contains(".lproj/")
            let isLproj = buildFilePath.extension == "lproj"

            var element: (element: PBXFileElement, path: AbsolutePath)?

            if isLocalized {
                guard let (group, path) = fileElements.variantGroup(containing: buildFilePath) else {
                    throw BuildPhaseGenerationError.missingFileReference(buildFilePath, target.name)
                }

                // Xcode automatically copies the string files for some files (i.e. .intentdefinition files), hence we need
                // to remove them from the Copy Resources build phase
                if let suffix = path.suffix, ignoredVariantGroupExtensions.contains(suffix) {
                    continue
                }

                element = (group, path)
            } else if !isLproj {
                guard let fileReference = fileElements.file(path: buildFilePath) else {
                    throw BuildPhaseGenerationError.missingFileReference(buildFilePath, target.name)
                }
                element = (fileReference, buildFilePath)
            }
            if let element, buildFilesCache.contains(element.path) == false {
                let tags = resource.tags.sorted()
                let settings: [String: BuildFileSetting]? = !tags.isEmpty ? ["ASSET_TAGS": .array(tags)] : nil

                let pbxBuildFile = PBXBuildFile(file: element.element, settings: settings)
                pbxBuildFile.applyCondition(resource.inclusionCondition, applicableTo: target)
                pbxBuildFiles.append(pbxBuildFile)
                buildFilesCache.insert(element.path)
            }
        }
        return pbxBuildFiles
    }

    private func generateCoreDataModels(
        coreDataModels: [CoreDataModel],
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) -> [PBXBuildFile] {
        let coreDataModels = coreDataModels.sorted { $0.path < $1.path }
        return coreDataModels.map {
            self.generateCoreDataModel(
                coreDataModel: $0,
                fileElements: fileElements,
                pbxproj: pbxproj
            )
        }
    }

    private func generateCoreDataModel(
        coreDataModel: CoreDataModel,
        fileElements: ProjectFileElements,
        pbxproj _: PBXProj
    ) -> PBXBuildFile {
        guard let currentVersion = coreDataModel.currentVersion else {
            fatalError("currentVersion for core data model \(coreDataModel.path) not found")
        }
        let path = coreDataModel.path
        let currentVersionPath = path.appending(component: "\(currentVersion).xcdatamodel")
        // swiftlint:disable:next force_cast
        let modelReference = fileElements.group(path: path)! as! XCVersionGroup
        let currentVersionReference = fileElements.file(path: currentVersionPath)!
        modelReference.currentVersion = currentVersionReference

        let pbxBuildFile = PBXBuildFile(file: modelReference)
        return pbxBuildFile
    }

    private func generateResourceBundle(
        path: AbsolutePath,
        target: Target,
        graphTraverser: GraphTraversing,
        fileElements: ProjectFileElements
    ) throws -> [PBXBuildFile] {
        let bundles = graphTraverser.resourceBundleDependencies(path: path, name: target.name)
            .sorted()
        let buildFiles = bundles.compactMap { dependency -> PBXBuildFile? in
            switch dependency {
            case let .bundle(path: path, condition: condition):
                let buildFile = PBXBuildFile(file: fileElements.file(path: path))
                buildFile.applyCondition(condition, applicableTo: target)
                return buildFile
            case let .product(target: targetName, _, _, condition: condition):
                let buildFile = PBXBuildFile(file: fileElements.product(target: targetName))
                buildFile.applyCondition(condition, applicableTo: target)
                return buildFile
            default:
                return nil
            }
        }

        return buildFiles
    }

    func generateAppExtensionsBuildPhase(
        path: AbsolutePath,
        target: Target,
        graphTraverser: GraphTraversing,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        let appExtensions = graphTraverser.appExtensionDependencies(path: path, name: target.name).sorted()
        guard !appExtensions.isEmpty else { return }

        let appExtensionsBuildPhase = PBXCopyFilesBuildPhase(dstSubfolderSpec: .plugins, name: "Embed Foundation Extensions")
        pbxproj.add(object: appExtensionsBuildPhase)
        pbxTarget.buildPhases.append(appExtensionsBuildPhase)

        let pbxBuildFiles: [PBXBuildFile] = appExtensions.compactMap { extensionTargetReference in
            guard let fileReference = fileElements.product(target: extensionTargetReference.target.name) else { return nil }

            let pbxBuildFile = PBXBuildFile(file: fileReference, settings: ["ATTRIBUTES": ["RemoveHeadersOnCopy"]])
            pbxBuildFile.applyCondition(extensionTargetReference.condition, applicableTo: target)
            return pbxBuildFile
        }

        pbxBuildFiles.forEach { pbxproj.add(object: $0) }
        appExtensionsBuildPhase.files = pbxBuildFiles
    }

    func generateEmbedWatchBuildPhase(
        path: AbsolutePath,
        target: Target,
        graphTraverser: GraphTraversing,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        let targetDependencies = graphTraverser.directLocalTargetDependencies(path: path, name: target.name).sorted()
        let watchApps = targetDependencies.filter { $0.target.isEmbeddableWatchApplication() }
        guard !watchApps.isEmpty else { return }

        let embedWatchAppBuildPhase = PBXCopyFilesBuildPhase(
            dstPath: "$(CONTENTS_FOLDER_PATH)/Watch",
            dstSubfolderSpec: .productsDirectory,
            name: "Embed Watch Content"
        )
        pbxproj.add(object: embedWatchAppBuildPhase)
        pbxTarget.buildPhases.append(embedWatchAppBuildPhase)

        let pbxBuildFiles: [PBXBuildFile] = watchApps.compactMap { appTargetReference in
            guard let fileReference = fileElements.product(target: appTargetReference.target.name) else { return nil }

            let pbxBuildFile = PBXBuildFile(file: fileReference, settings: ["ATTRIBUTES": ["RemoveHeadersOnCopy"]])
            pbxBuildFile.applyCondition(appTargetReference.condition, applicableTo: target)
            return pbxBuildFile
        }

        pbxBuildFiles.forEach { pbxproj.add(object: $0) }
        embedWatchAppBuildPhase.files = pbxBuildFiles
    }

    func generateEmbedAppClipsBuildPhase(
        path: AbsolutePath,
        target: Target,
        graphTraverser: GraphTraversing,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        guard target.product == .app else {
            return
        }

        guard let appClipTargetReference = graphTraverser.appClipDependencies(path: path, name: target.name) else {
            return
        }
        var pbxBuildFiles = [PBXBuildFile]()

        let embedAppClipsBuildPhase = PBXCopyFilesBuildPhase(
            dstPath: "$(CONTENTS_FOLDER_PATH)/AppClips",
            dstSubfolderSpec: .productsDirectory,
            name: "Embed App Clips"
        )
        pbxproj.add(object: embedAppClipsBuildPhase)
        pbxTarget.buildPhases.append(embedAppClipsBuildPhase)

        let refs = fileElements.product(target: appClipTargetReference.target.name)

        let pbxBuildFile = PBXBuildFile(file: refs, settings: ["ATTRIBUTES": ["RemoveHeadersOnCopy"]])
        pbxBuildFile.applyCondition(appClipTargetReference.condition, applicableTo: target)
        pbxBuildFiles.append(pbxBuildFile)
        pbxBuildFiles.forEach { pbxproj.add(object: $0) }
        embedAppClipsBuildPhase.files = pbxBuildFiles
    }

    func generateEmbedXPCServicesBuildPhase(
        path: AbsolutePath,
        target: Target,
        graphTraverser: GraphTraversing,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        let targetDependencies = graphTraverser.directLocalTargetDependencies(path: path, name: target.name).sorted()
        let xpcServices = targetDependencies.filter { $0.target.isEmbeddableXPCService() }
        guard !xpcServices.isEmpty else { return }

        let embedXPCServicesBuildPhase = PBXCopyFilesBuildPhase(
            dstPath: "$(CONTENTS_FOLDER_PATH)/XPCServices",
            dstSubfolderSpec: .productsDirectory,
            name: "Embed XPC Services"
        )
        pbxproj.add(object: embedXPCServicesBuildPhase)
        pbxTarget.buildPhases.append(embedXPCServicesBuildPhase)

        let pbxBuildFiles: [PBXBuildFile] = xpcServices.compactMap { graphTarget in
            guard let fileReference = fileElements.product(target: graphTarget.target.name) else { return nil }

            let pbxBuildFile = PBXBuildFile(file: fileReference, settings: ["ATTRIBUTES": ["RemoveHeadersOnCopy"]])
            if !graphTarget.target.isExclusiveTo(.macOS) {
                pbxBuildFile.applyPlatformFilters([.macos])
            }
            return pbxBuildFile
        }

        pbxBuildFiles.forEach { pbxproj.add(object: $0) }
        embedXPCServicesBuildPhase.files = pbxBuildFiles
    }

    func generateEmbedSystemExtensionBuildPhase(
        path: AbsolutePath,
        target: Target,
        graphTraverser: GraphTraversing,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        let targetDependencies = graphTraverser.directLocalTargetDependencies(path: path, name: target.name).sorted()
        let systemExtensions = targetDependencies.filter { $0.target.isEmbeddableSystemExtension() }
        guard !systemExtensions.isEmpty else { return }

        let embedSystemExtensionsBuildPhase = PBXCopyFilesBuildPhase(
            dstPath: "$(CONTENTS_FOLDER_PATH)/Library/SystemExtensions",
            dstSubfolderSpec: .productsDirectory,
            name: "Embed System Extensions"
        )
        pbxproj.add(object: embedSystemExtensionsBuildPhase)
        pbxTarget.buildPhases.append(embedSystemExtensionsBuildPhase)

        let pbxBuildFiles: [PBXBuildFile] = systemExtensions.compactMap { graphTarget in
            guard let fileReference = fileElements.product(target: graphTarget.target.name) else { return nil }

            let pbxBuildFile = PBXBuildFile(file: fileReference, settings: ["ATTRIBUTES": ["RemoveHeadersOnCopy"]])
            if !graphTarget.target.isExclusiveTo(.macOS) {
                pbxBuildFile.applyPlatformFilters([.macos])
            }
            return pbxBuildFile
        }

        pbxBuildFiles.forEach { pbxproj.add(object: $0) }
        embedSystemExtensionsBuildPhase.files = pbxBuildFiles
    }

    func generateExtensionKitExtensionsBuildPhase(
        path: AbsolutePath,
        target: Target,
        graphTraverser: GraphTraversing,
        pbxTarget: PBXTarget,
        fileElements: ProjectFileElements,
        pbxproj: PBXProj
    ) throws {
        let extensions = graphTraverser.extensionKitExtensionDependencies(path: path, name: target.name).sorted()
        guard !extensions.isEmpty else { return }

        let extensionKitExtensionsBuildPhase = PBXCopyFilesBuildPhase(
            dstPath: "$(EXTENSIONS_FOLDER_PATH)",
            dstSubfolderSpec: .productsDirectory,
            name: "Embed ExtensionKit Extensions"
        )
        pbxproj.add(object: extensionKitExtensionsBuildPhase)
        pbxTarget.buildPhases.append(extensionKitExtensionsBuildPhase)

        let pbxBuildFiles: [PBXBuildFile] = extensions.compactMap { extensionTargetReference in
            guard let fileReference = fileElements.product(target: extensionTargetReference.target.name) else { return nil }

            let pbxBuildFile = PBXBuildFile(file: fileReference, settings: ["ATTRIBUTES": ["RemoveHeadersOnCopy"]])
            pbxBuildFile.applyCondition(extensionTargetReference.condition, applicableTo: target)
            return pbxBuildFile
        }

        pbxBuildFiles.forEach { pbxproj.add(object: $0) }
        extensionKitExtensionsBuildPhase.files = pbxBuildFiles
    }
}
