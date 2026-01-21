import Foundation
import GekoCore
import GekoGraph
import ProjectDescription
@testable import GekoKit

final class MockGeneratorFactory: GeneratorFactorying {
    var invokedTest = false
    var invokedTestCount = 0
    var invokedTestParameters: (
        config: Config,
        testsCacheDirectory: AbsolutePath,
        testPlan: String?,
        includedTargets: Set<String>,
        excludedTargets: Set<String>,
        skipUITests: Bool
    )?
    var invokedTestParametersList =
        [(
            config: Config,
            testsCacheDirectory: AbsolutePath,
            testPlan: String?,
            includedTargets: Set<String>,
            excludedTargets: Set<String>,
            skipUITests: Bool
        )]()
    var stubbedTestResult: Generating!

    func test(
        config: Config,
        testsCacheDirectory: AbsolutePath,
        testPlan: String?,
        includedTargets: Set<String>,
        excludedTargets: Set<String>,
        skipUITests: Bool
    ) -> Generating {
        invokedTest = true
        invokedTestCount += 1
        invokedTestParameters = (
            config,
            testsCacheDirectory,
            testPlan,
            includedTargets,
            excludedTargets,
            skipUITests
        )
        invokedTestParametersList
            .append((
                config,
                testsCacheDirectory,
                testPlan,
                includedTargets,
                excludedTargets,
                skipUITests
            ))
        return stubbedTestResult
    }

    var invokedDefault = false
    var invokedDefaultCount = 0
    var stubbedDefaultResult: Generating!

    func `default`(config _: Config) -> Generating {
        invokedDefault = true
        invokedDefaultCount += 1
        return stubbedDefaultResult
    }
    
    var invokedCache = false
    var invokedCacheCount = 0
    var invokedCacheParameters: (
        config: Config,
        focusedTargets: Set<String>,
        cacheProfile: ProjectDescription.Cache.Profile,
        focusDirectDependencies: Bool,
        focusTests: Bool,
        unsafe: Bool,
        dependenciesOnly: Bool,
        scheme: String?
    )?
    var invokedCacheParametersList =
        [(
            config: Config,
            focusedTargets: Set<String>,
            cacheProfile: ProjectDescription.Cache.Profile,
            focusDirectDependencies: Bool,
            focusTests: Bool,
            unsafe: Bool,
            dependenciesOnly: Bool,
            scheme: String?
        )]()
    var stubbedCacheResult: Generating!
    func cache(
        config: Config,
        focusedTargets: Set<String>,
        cacheProfile: ProjectDescription.Cache.Profile,
        focusDirectDependencies: Bool,
        focusTests: Bool,
        unsafe: Bool,
        dependenciesOnly: Bool,
        scheme: String?
    ) -> GekoKit.Generating {
        invokedCache = true
        invokedCacheCount += 1
        invokedCacheParameters = (
            config,
            focusedTargets,
            cacheProfile,
            focusDirectDependencies,
            focusTests,
            unsafe,
            dependenciesOnly,
            scheme
        )
        invokedCacheParametersList.append((
            config,
            focusedTargets,
            cacheProfile,
            focusDirectDependencies,
            focusTests,
            unsafe,
            dependenciesOnly,
            scheme
        ))
        return stubbedCacheResult
    }

    var invokedFocus = false
    var invokedFocusCount = 0
    var invokedFocusParameters: (
        config: Config,
        focusedTargets: Set<String>,
        focusTests: Bool,
        scheme: String?
    )?
    var invokedFocusParametersList =
        [(
            config: Config,
            focusedTargets: Set<String>,
            focusTests: Bool,
            scheme: String?
        )]()
    var stubbedFocusResult: Generating!

    func focus(
        config: Config,
        focusedTargets: Set<String>,
        focusTests: Bool,
        scheme: String?
    ) -> GekoKit.Generating {
        invokedFocus = true
        invokedFocusCount += 1
        invokedFocusParameters = (
            config,
            focusedTargets,
            focusTests,
            scheme
        )
        invokedFocusParametersList.append((
            config,
            focusedTargets,
            focusTests,
            scheme
        ))
        return stubbedFocusResult
    }
}
