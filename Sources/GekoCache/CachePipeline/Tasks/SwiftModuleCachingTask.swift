import Foundation
import GekoCore
import GekoGraph
import GekoSupport
import ProjectDescription

public final class SwiftModuleCachingTask: CacheTask {
    
    // MARK: - Attributes
    
    private let xcframeworkContentHasher: XCFrameworksContentHashing
    
    private let cache: CacheStoring
    
    private let swiftModulesBuilder: SwiftModulesBuilding
    
    private let clock: Clock
    
    private let timeTakenLoggerFormatter: TimeTakenLoggerFormatting

    private let swiftModuleMetadataProvider: SwiftModuleMetadataProviding
    
    private let xcframeworkMetadataProvider: XCFrameworkMetadataProviding
    
    // MARK: - Initialization
    
    public convenience init(
        contentHasher: ContentHashing,
        cache: CacheStoring
    ) {
        self.init(
            xcframeworkContentHasher: XCFrameworksContentHasher(contentHasher: contentHasher),
            cache: cache,
            swiftModulesBuilder: SwiftModulesBuilder(),
            clock: WallClock(),
            timeTakenLoggerFormatter: TimeTakenLoggerFormatter(),
            swiftModuleMetadataProvider: SwiftModuleMetadataProvider(),
            xcframeworkMetadataProvider: XCFrameworkMetadataProvider()
        )
    }

    public init(
        xcframeworkContentHasher: XCFrameworksContentHashing,
        cache: CacheStoring,
        swiftModulesBuilder: SwiftModulesBuilding,
        clock: Clock,
        timeTakenLoggerFormatter: TimeTakenLoggerFormatting,
        swiftModuleMetadataProvider: SwiftModuleMetadataProviding,
        xcframeworkMetadataProvider: XCFrameworkMetadataProviding
    ) {
        self.xcframeworkContentHasher = xcframeworkContentHasher
        self.cache = cache
        self.swiftModulesBuilder = swiftModulesBuilder
        self.clock = clock
        self.timeTakenLoggerFormatter = timeTakenLoggerFormatter
        self.swiftModuleMetadataProvider = swiftModuleMetadataProvider
        self.xcframeworkMetadataProvider = xcframeworkMetadataProvider
    }

    // MARK: - CacheTask

    public func run(context: inout CacheContext) async throws {
        guard context.cacheProfile.options.swiftModuleCacheEnabled else { return }
        guard let graph = context.graph else {
            throw CacheTaskError.cacheContextValueUninitialized
        }

        // Caclulate hashes for xcframeworks if swiftmodule cache enabled
        let hashesByXCFrameworks = try xcframeworkContentHasher.contentHashes(
            for: graph,
            cacheProfile: context.cacheProfile,
            cacheUserVersion: context.config.cache?.version,
            cacheOutputType: context.outputType,
            cacheDestination: context.destination
        )

        // Replace swiftinterface with already cached swiftmodules
        try await replaceSwiftInterfaces(
            rootPath: context.path,
            cacheProfile: context.cacheProfile,
            hashesByXCFrameworks: hashesByXCFrameworks,
            logging: true
        )

        // Archive only not cached yet swiftmodules
        let filteredHashesByXCFramework = try await filterNotCachedXCFrameworks(hashesByXCFrameworks: hashesByXCFrameworks)
        try await archive(
            graph: graph,
            profile: context.cacheProfile,
            destination: context.destination,
            hashedXCFrameworks: filteredHashesByXCFramework
        )
        
        // Replace remaining ones
        try await replaceSwiftInterfaces(
            rootPath: context.path,
            cacheProfile: context.cacheProfile,
            hashesByXCFrameworks: filteredHashesByXCFramework
        )
    }
    
    // MARK: - Private
    
    private func archive(
        graph: Graph,
        profile: ProjectDescription.Cache.Profile,
        destination: CacheFrameworkDestination,
        hashedXCFrameworks: [AbsolutePath: String]
    ) async throws {
        try await FileHandler.shared.inTemporaryDirectory { outputDirectory in
            try await self.swiftModulesBuilder.build(
                with: graph,
                profile: profile,
                destination: destination,
                hashedXCFrameworks: hashedXCFrameworks,
                into: outputDirectory
            )
            
            try await self.store(
                hashedXCFrameworks: hashedXCFrameworks,
                outputDirectory: outputDirectory,
                cacheProfile: profile
            )
        }
    }
    
    private func store(
        hashedXCFrameworks: [AbsolutePath: String],
        outputDirectory: AbsolutePath,
        cacheProfile: ProjectDescription.Cache.Profile
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (path, hash) in hashedXCFrameworks {
                let name = path.basenameWithoutExt
                group.addTask {
                    try await self.cache.store(
                        name: name,
                        hash: hash,
                        paths: FileHandler.shared.glob(outputDirectory, glob: "\(name).swiftmodule")
                    )
                }
            }
            try await group.waitForAll()
        }
    }
    
    private func filterNotCachedXCFrameworks(
        hashesByXCFrameworks: [AbsolutePath: String]
    ) async throws -> [AbsolutePath: String] {
        try await withThrowingTaskGroup(of: (AbsolutePath, String)?.self) { group in
            for (path, hash) in hashesByXCFrameworks {
                group.addTask {
                    let name = path.basenameWithoutExt
                    if try await !self.cache.exists(name: name, hash: hash) {
                        return (path, hash)
                    }
                    return nil
                }
            }
            
            let result = try await group
                .compactMap { $0 }
                .reduce(into: [:]) { $0[$1.0] = $1.1}
            return result
        }
    }

    private func replaceSwiftInterfaces(
        rootPath: AbsolutePath,
        cacheProfile: ProjectDescription.Cache.Profile,
        hashesByXCFrameworks: [AbsolutePath: String],
        logging: Bool = false
    ) async throws {
        guard !hashesByXCFrameworks.isEmpty else { return }
        let fetchedSwiftModules = try await fetch(hashesByXCFrameworks: hashesByXCFrameworks, logging: logging)
        let swiftinterfacesDir = rootPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftinterfacesDirectoryName
        ])
        if !FileHandler.shared.exists(swiftinterfacesDir)
        {
            try FileHandler.shared.createFolder(swiftinterfacesDir)
        }
        let swiftModuleGlob = cacheProfile.platforms.isEmpty ? "*.swiftmodule" : "*{\(cacheProfile.platforms.keys.map { $0.rawValue }.joined(separator: ","))}*.swiftmodule"
        
        for (xcframeworkPath, swiftModuleFolderPath) in fetchedSwiftModules {
            // We need path to {ModulName}.swiftmodule folder
            let swiftModules = FileHandler.shared.glob(swiftModuleFolderPath, glob: swiftModuleGlob)
            guard !swiftModules.isEmpty else {
                continue
            }
            for swiftModuleFilePath in swiftModules {
                let swiftModuleMetadata = try swiftModuleMetadataProvider.loadMetadata(at: swiftModuleFilePath)
                let xcframeworkMetadata = try xcframeworkMetadataProvider.infoPlist(xcframeworkPath: xcframeworkPath)
                
                // We need to find a library that matches the parameters of the swiftmodule build target
                let library = xcframeworkMetadata.libraries.first(where: {
                    $0.architectures.contains(swiftModuleMetadata.arch) &&
                    $0.platform == swiftModuleMetadata.platform.xcframeworkPlatform &&
                    $0.platformVariant == swiftModuleMetadata.platformVariant?.xcframeworkPlatformVariant
                })
                
                guard let library else { continue }
                // Check that XCFramework has a swiftmodule folder
                let librarySwiftModuleFolderPath = xcframeworkMetadataProvider.swiftmoduleFolderPath(
                    xcframeworkPath: xcframeworkPath,
                    library: library
                )
                guard let librarySwiftModuleFolderPath else { continue }
                
                // Target path to save cached swiftmodule
                let librarySwiftModulePath = librarySwiftModuleFolderPath.appending(component: swiftModuleFilePath.basename)
                
                guard FileHandler.shared.exists(librarySwiftModuleFolderPath) else { continue }
                
                // Move all replaced swiftinterfaces to a separate dir.
                // We move the files to a separate directory. This is necessary for utilities tied to parsing swiftintrfaces
                let pathsToMove = try FileHandler.shared
                    .contentsOfDirectory(librarySwiftModuleFolderPath)
                    .filter { !$0.basename.contains("swiftmodule") }
                let swiftinterfacesModuleDir = swiftinterfacesDir.appending(component: library.binaryName)
                if !FileHandler.shared.exists(swiftinterfacesModuleDir) {
                    try FileHandler.shared.createFolder(swiftinterfacesModuleDir)
                }
                try pathsToMove.forEach {
                    let destinationPath = swiftinterfacesModuleDir.appending(component: $0.basename)
                    if FileHandler.shared.exists(destinationPath) {
                        try FileHandler.shared.delete(destinationPath)
                    }
                    try FileHandler.shared.move(from: $0, to: destinationPath)
                }

                // If swiftmodule already exist and we have new one, we should replace old one
                if FileHandler.shared.exists(librarySwiftModulePath) {
                    try FileHandler.shared.delete(librarySwiftModulePath)
                }
                try FileHandler.shared.copy(from: swiftModuleFilePath, to: librarySwiftModuleFolderPath.appending(component: swiftModuleFilePath.basename))
            }
        }
    }
    
    /// Method fetches remote cached swift modules
    /// - returns: Hash with path to xcframework as a key, and path to swiftmodule cache as a value
    private func fetch(
        hashesByXCFrameworks: [AbsolutePath: String],
        logging: Bool = false
    ) async throws -> [AbsolutePath: AbsolutePath] {
        guard !hashesByXCFrameworks.isEmpty else { return [:] }
        let timer = clock.startTimer()
        let fetchedModules = try await hashesByXCFrameworks.concurrentMap { path, hash -> (AbsolutePath, AbsolutePath?) in
            let name = path.basenameWithoutExt
            if try await self.cache.exists(name: name, hash: hash) {
                let swiftModulePath = try await self.cache.fetch(name: name, hash: hash)
                return (path, swiftModulePath)
            } else {
                return (path, nil)
            }
        }.reduce(into: [AbsolutePath: AbsolutePath]()) { acc, next in
            guard let path = next.1 else { return }
            acc[next.0] = path
        }
        if logging {
            logger.notice(timeTakenLoggerFormatter.timeTakenMessage(message: "swiftmodule cache fetch", for: timer))
        }
        return fetchedModules
    }
}
