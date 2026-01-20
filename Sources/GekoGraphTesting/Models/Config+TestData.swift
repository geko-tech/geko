import Foundation
import ProjectDescription
@testable import GekoGraph

extension Config {
    public static func test(
        compatibleXcodeVersions: CompatibleXcodeVersions = .all,
        cloud: Cloud? = Cloud.test(),
        cache: Cache? = Cache.test(),
        swiftVersion: Version? = nil,
        plugins: [PluginLocation] = [],
        generationOptions: GenerationOptions = Config.default.generationOptions,
        preFetchScripts: [Script] = [],
        preGenerateScripts: [Script] = [],
        postGenerateScripts: [Script] = [],
        cocoapodsUseBundler: Bool = false
    ) -> Config {
        .init(
            compatibleXcodeVersions: compatibleXcodeVersions,
            cloud: cloud,
            cache: cache,
            swiftVersion: swiftVersion,
            plugins: plugins,
            generationOptions: generationOptions,
            preFetchScripts: preFetchScripts,
            preGenerateScripts: preGenerateScripts,
            postGenerateScripts: postGenerateScripts,
            cocoapodsUseBundler: cocoapodsUseBundler
        )
    }
}

extension Config.GenerationOptions {
    public static func test(
        resolveDependenciesWithSystemScm: Bool = false,
        disablePackageVersionLocking: Bool = false,
        clonedSourcePackagesDirPath: AbsolutePath? = nil,
        staticSideEffectsWarningTargets: Config.GenerationOptions.StaticSideEffectsWarningTargets = .all,
        enforceExplicitDependencies: Bool = false
    ) -> Self {
        .options(
            resolveDependenciesWithSystemScm: resolveDependenciesWithSystemScm,
            disablePackageVersionLocking: disablePackageVersionLocking,
            clonedSourcePackagesDirPath: clonedSourcePackagesDirPath,
            staticSideEffectsWarningTargets: staticSideEffectsWarningTargets,
            enforceExplicitDependencies: enforceExplicitDependencies
        )
    }
}
