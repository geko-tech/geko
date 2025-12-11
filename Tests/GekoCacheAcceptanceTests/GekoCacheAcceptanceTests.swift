#if os(macOS)
import Foundation
import struct ProjectDescription.AbsolutePath
import GekoAcceptanceTesting
import GekoSupport
import GekoSupportTesting
import XcodeProj
import XCTest
import PathKit

final class CacheAcceptanceTestsAllTargets: GekoAcceptanceTestCase {
    func test_ios_app_generate_cache() async throws {
        throw XCTSkip("// TODO: Github find some other public cdn precompiled library or replace with orig source")
        
        // Given
        TestingLogHandler.reset()
        let expectedTargetsFeaturePodA = ["FeaturePodA-Unit-Tests"]
        try setUpFixture(.iosAppWorkspaceWithCocoapods)

        // When
        try await run(FetchCommand.self)
        try await run(GenerateCommand.self, arguments: ["--cache", "--ignore-remote-cache"])

        // Then
        // Check all expected targets was cached
        XCTAssertStandardOutput(pattern: "Targets to be cached now count: 19")
        XCTAssertStandardOutput(pattern: "Start building cacheable targets for platform iOS")
        XCTAssertStandardOutput(pattern: "Storing 19 cacheable targets")
        XCTAssertStandardOutput(pattern: "Stored target: FeaturePodA, FeaturePodA-FeaturePodAResources, FeaturePodA-Unit-TestsGekoGenerated, FeaturePodAInterfaces, FeaturePodB, FeaturePodB-FeaturePodBResources, FeaturePodB-Unit-TestsGekoGenerated, FeaturePodBInterfaces, InterimSinglePod, InterimSinglePod-Unit-TestsGekoGenerated, MultiPod, MultiPod-MultiPodTestsResources, MultiPod-Unit-TestsGekoGenerated, MultiPodInterfaces, MultiPodMock, OrphanSinglePod, OrphanSinglePod-Unit-TestsGekoGenerated, SinglePod, SinglePod-Unit-TestsGekoGenerated")
        XCTAssertStandardOutput(pattern: "All cacheable targets have been cached successfully as frameworks with simulator destination.")

        // Check FeautrePodA project remove all cached targets
        let featurePodAXCProjPath = try XCTUnwrap(FileHandler.shared.glob(fixturePath, glob: "**/FeaturePodA.xcodeproj").first)
        let featurePodAXCProj = try XcodeProj(pathString: featurePodAXCProjPath.pathString)
        let featurePodTargets = featurePodAXCProj.pbxproj.projects.first?.targets.map { $0.name }
        XCTAssertEqual(featurePodTargets, expectedTargetsFeaturePodA)

        // Rebuild with same cache
        // When
        TestingLogHandler.reset()
        try await run(GenerateCommand.self, arguments: ["--cache", "--ignore-remote-cache"])

        // Then
        XCTAssertStandardOutput(
            pattern:
            """
            All cacheable targets are already cached
            """
        )
    }
}

final class CacheAcceptanceTestsCacheWithFocus: GekoAcceptanceTestCase {
    func test_ios_app_generate_cache_with_focus() async throws {
        throw XCTSkip("// TODO: Github find some other public cdn precompiled library or replace with orig source")
        
        // Given
        TestingLogHandler.reset()
        let expectedTargetsFeaturePodA = ["FeaturePodA", "FeaturePodA-FeaturePodAResources"]
        let expectedAppTargetDependencies = [
            "App-NotificationContentExtension",
            "App-NotificationServiceExtension",
            "App-WhoCallsExtension",
            "FeaturePodA"
        ].sorted()
        try setUpFixture(.iosAppWorkspaceWithCocoapods)

        // When
        try await run(FetchCommand.self)
        try await run(GenerateCommand.self, arguments: ["App", "FeaturePodA", "--cache", "--ignore-remote-cache"])

        // Then
        XCTAssertStandardOutput(pattern: "Targets to be cached now count: 9")
        XCTAssertStandardOutput(pattern: "Start building cacheable targets for platform iOS")
        XCTAssertStandardOutput(pattern: "Storing 9 cacheable targets")
        XCTAssertStandardOutput(pattern: "Stored target: FeaturePodAInterfaces, FeaturePodB, FeaturePodB-FeaturePodBResources, FeaturePodBInterfaces, InterimSinglePod, MultiPod, MultiPodInterfaces, OrphanSinglePod, SinglePod")
        XCTAssertStandardOutput(pattern: "All cacheable targets have been cached successfully as frameworks with simulator destination.")

        // Check FeautrePodA project remove all cached targets
        let featurePodAXCProjPath = try XCTUnwrap(FileHandler.shared.glob(fixturePath, glob: "**/FeaturePodA.xcodeproj").first)
        let featurePodAXCProj = try XcodeProj(pathString: featurePodAXCProjPath.pathString)
        let featurePodTargets = featurePodAXCProj.pbxproj.projects.first?.targets.map { $0.name }.sorted()
        XCTAssertEqual(featurePodTargets, expectedTargetsFeaturePodA)

        // Check App containts only FeaturePodA target dependency and non cachable targets
        let appProj = try XcodeProj(pathString: xcodeprojPath.pathString)
        let appTargetDeps = try XCTUnwrap(appProj.pbxproj.projects
            .first?.targets
            .first(where: { $0.name == "App" }))
            .dependencies.map { $0.name ?? "" }
            .sorted()
        XCTAssertEqual(appTargetDeps, expectedAppTargetDependencies)

        // Rebuild with same cache
        // When
        TestingLogHandler.reset()
        try await run(GenerateCommand.self, arguments: ["App", "FeaturePodA", "--cache", "--ignore-remote-cache"])

        // Then
        XCTAssertStandardOutput(
            pattern:
            """
            All cacheable targets are already cached
            """
        )
    }
}

final class CacheAcceptanceTestsWithFocusAndFocusDirectDependenciesSafeMode: GekoAcceptanceTestCase {
    func test_ios_app_generate_cache_with_focus_and_focus_direct_dependencies_safe_mode() async throws {
        throw XCTSkip("// TODO: Github find some other public cdn precompiled library or replace with orig source")
        
        // Given
        TestingLogHandler.reset()
        let expectedFeaturePodATargetDependencies = [
            "FeaturePodAInterfaces",
            "FeaturePodA-FeaturePodAResources",
            "SinglePod",
            "MultiPod",
            "MultiPodInterfaces"
        ].sorted()
        let expectedFeaturePodBTargetDependencies = [
            "FeaturePodB-FeaturePodBResources",
            "SinglePod"
        ].sorted()

        try setUpFixture(.iosAppWorkspaceWithCocoapods)

        // When
        try await run(FetchCommand.self)
        try await run(GenerateCommand.self, arguments: [
            "App",
            "FeaturePodA",
            "--cache",
            "--ignore-remote-cache",
            "--focus-direct-dependencies"
        ])

        // Then
        XCTAssertStandardOutput(pattern: "Targets to be cached now count: 2")
        XCTAssertStandardOutput(pattern: "Start building cacheable targets for platform iOS")
        XCTAssertStandardOutput(pattern: "Storing 2 cacheable targets")
        XCTAssertStandardOutput(pattern: "Stored target: FeaturePodBInterfaces, OrphanSinglePod")
        XCTAssertStandardOutput(pattern: "All cacheable targets have been cached successfully as frameworks with simulator destination.")

        // Check FeautrePodB project cache OrphanSinglePod
        let featurePodBXCProjPath = try XCTUnwrap(FileHandler.shared.glob(fixturePath, glob: "**/FeaturePodB.xcodeproj").first)
        let featurePodBXCProj = try XcodeProj(pathString: featurePodBXCProjPath.pathString)
        let featurePodBTargetDeps = try XCTUnwrap(featurePodBXCProj.pbxproj.projects
            .first?.targets
            .first(where: { $0.name == "FeaturePodB" }))
            .dependencies.map { $0.name ?? "" }
            .sorted()
        XCTAssertEqual(featurePodBTargetDeps, expectedFeaturePodBTargetDependencies)

        // Check FeaturePodA project not cache direct deps
        let featurePodAXCProjPath = try XCTUnwrap(FileHandler.shared.glob(fixturePath, glob: "**/FeaturePodA.xcodeproj").first)
        let featurePodAXCProj = try XcodeProj(pathString: featurePodAXCProjPath.pathString)
        let featurePodATargetDeps = try XCTUnwrap(featurePodAXCProj.pbxproj.projects
            .first?.targets
            .first(where: { $0.name == "FeaturePodA" }))
            .dependencies.map { $0.name ?? "" }
            .sorted()
        XCTAssertEqual(featurePodATargetDeps, expectedFeaturePodATargetDependencies)

        // Rebuild with same cache
        // When
        TestingLogHandler.reset()
        try await run(GenerateCommand.self, arguments: [
            "App",
            "FeaturePodA",
            "--cache",
            "--ignore-remote-cache",
            "--focus-direct-dependencies"
        ])

        // Then
        XCTAssertStandardOutput(
            pattern:
            """
            All cacheable targets are already cached
            """
        )
    }
}

final class CacheAcceptanceTestsWithFocusAndFocusDirectDependenciesUnsafeMode: GekoAcceptanceTestCase {
    func test_ios_app_generate_cache_with_focus_and_focus_direct_dependencies_unsafe_mode() async throws {
        throw XCTSkip("// TODO: Github find some other public cdn precompiled library or replace with orig source")
        
        // Given
        TestingLogHandler.reset()
        let expectedFeaturePodATargetDependencies = [
            "FeaturePodAInterfaces",
            "FeaturePodA-FeaturePodAResources",
            "SinglePod",
            "MultiPod",
            "MultiPodInterfaces"
        ].sorted()

        try setUpFixture(.iosAppWorkspaceWithCocoapods)

        // When
        try await run(FetchCommand.self)
        try await run(GenerateCommand.self, arguments: [
            "App",
            "FeaturePodA",
            "--cache",
            "--ignore-remote-cache",
            "--focus-direct-dependencies",
            "--unsafe"
        ])

        // Then
        XCTAssertStandardOutput(pattern: "Targets to be cached now count: 5")
        XCTAssertStandardOutput(pattern: "Start building cacheable targets for platform iOS")
        XCTAssertStandardOutput(pattern: "Storing 5 cacheable targets")
        XCTAssertStandardOutput(pattern: "Stored target: FeaturePodB, FeaturePodB-FeaturePodBResources, FeaturePodBInterfaces, InterimSinglePod, OrphanSinglePod")
        XCTAssertStandardOutput(pattern: "All cacheable targets have been cached successfully as frameworks with simulator destination.")

        // Check App doesn't have FeaturePodB target dependency
        let appXCProj = try XcodeProj(pathString: xcodeprojPath.pathString)
        let appTargetDeps = try XCTUnwrap(appXCProj.pbxproj.projects
            .first?.targets
            .first(where: { $0.name == "App" }))
            .dependencies.map { $0.name ?? "" }
            .sorted()
        XCTAssertFalse(appTargetDeps.contains("FeaturePodB"))

        // Check App-NotificationServiceExtension contains SinglePod deps
        let appExtensionTargetDeps = try XCTUnwrap(appXCProj.pbxproj.projects
            .first?.targets
            .first(where: { $0.name == "App-NotificationServiceExtension" }))
            .dependencies.map { $0.name ?? "" }
            .sorted()
        XCTAssertTrue(appExtensionTargetDeps.contains("SinglePod"))

        // Check FeaturePodA project not cache direct deps
        let featurePodAXCProjPath = try XCTUnwrap(FileHandler.shared.glob(fixturePath, glob: "**/FeaturePodA.xcodeproj").first)
        let featurePodAXCProj = try XcodeProj(pathString: featurePodAXCProjPath.pathString)
        let featurePodATargetDeps = try XCTUnwrap(featurePodAXCProj.pbxproj.projects
            .first?.targets
            .first(where: { $0.name == "FeaturePodA" }))
            .dependencies.map { $0.name ?? "" }
            .sorted()
        XCTAssertEqual(featurePodATargetDeps, expectedFeaturePodATargetDependencies)

        // Rebuild with same cache
        // When
        TestingLogHandler.reset()
        try await run(GenerateCommand.self, arguments: [
            "App",
            "FeaturePodA",
            "--cache",
            "--ignore-remote-cache",
            "--focus-direct-dependencies",
            "--unsafe"
        ])

        // Then
        XCTAssertStandardOutput(
            pattern:
            """
            All cacheable targets are already cached
            """
        )
    }
}

final class CacheAcceptanceTestsWithSwiftModuleCache: GekoAcceptanceTestCase {
    func test_ios_app_generate_cache_with_focus_swiftmodule_cache() async throws {
        throw XCTSkip("// TODO: Github find some other public cdn precompiled library or replace with orig source")
        
        // Given
        environment.swiftModuleCacheEnabled = true
        TestingLogHandler.reset()
        try setUpFixture(.iosAppWorkspaceWithCocoapods)

        // When
        try await run(FetchCommand.self)
        try await run(GenerateCommand.self, arguments: [
            "App",
            "FeaturePodA",
            "--cache",
            "--ignore-remote-cache",
            "--focus-direct-dependencies",
            "--unsafe"
        ])

        // Then
        XCTAssertStandardOutput(pattern: "Targets to be cached now count: 5")
        XCTAssertStandardOutput(pattern: "Start building cacheable targets for platform iOS")
        XCTAssertStandardOutput(pattern: "Storing 5 cacheable targets")
        XCTAssertStandardOutput(pattern: "Stored target: FeaturePodB, FeaturePodB-FeaturePodBResources, FeaturePodBInterfaces, InterimSinglePod, OrphanSinglePod")
        XCTAssertStandardOutput(pattern: "All cacheable targets have been cached successfully as frameworks with simulator destination.")
        XCTAssertStandardOutput(pattern: "Total time taken for swiftmodule cache fetch")

        // Check the SwiftJSON folder for the presence of the swiftmodule file and the absence of swiftinterface files
        let swiftmoduleFolderPath = fixturePath.appending(components: ["Geko", "Dependencies", "Cocoapods", "SwiftyJSON", "SwiftyJSON.xcframework", "ios-arm64_x86_64-simulator", "SwiftyJSON.framework","Modules","SwiftyJSON.swiftmodule"])
        let contents = try FileHandler.shared.contentsOfDirectory(swiftmoduleFolderPath)
        XCTAssertTrue(contents.map { $0.pathString.contains(".swiftmodule")}.allSatisfy({$0}))
        XCTAssertTrue(contents.map { !$0.pathString.contains(".swiftinterface")}.allSatisfy({$0}))

        // Rebuild with same cache
        // When
        TestingLogHandler.reset()
        try await run(GenerateCommand.self, arguments: [
            "App",
            "FeaturePodA",
            "--cache",
            "--ignore-remote-cache",
            "--focus-direct-dependencies",
            "--unsafe"
        ])

        // Then
        XCTAssertStandardOutput(
            pattern:
            """
            All cacheable targets are already cached
            """
        )
    }
}

#endif

// TODO: TVos simulator not available now
//final class CacheAcceptanceTestsWithMultiplatformCache: GekoAcceptanceTestCase {
//    func test_ios_app_generate_cache_with_focus_multiplatfrom_cache() async throws {
//        // Given
//        environment.swiftModuleCacheEnabled = true
//        TestingLogHandler.reset()
//        try setUpFixture(.iosAppWorkspaceWithMultiplatformCocoapods)
//
//        // When
//        try await run(FetchCommand.self)
//        try await run(GenerateCommand.self, arguments: [
//            "App",
//            "TVosApp",
//            "MultiPlatfromParentPod",
//            "--cache",
//            "--unsafe",
//            "--ignore-remote-cache",
//            "-P",
//            "all"
//        ])
//
//        // Then
//        XCTAssertStandardOutput(pattern: "Targets to be cached now count: 24")
//        XCTAssertStandardOutput(pattern: "Start building cacheable targets for platform iOS")
//        XCTAssertStandardOutput(pattern: "Start building cacheable targets for platform tvOS")
//        XCTAssertStandardOutput(pattern: "Start creating xcframeworks")
//        XCTAssertStandardOutput(pattern: "Start preparing bundles")
//        XCTAssertStandardOutput(pattern: "Storing 24 cacheable targets")
//        XCTAssertStandardOutput(pattern: "Stored target: FeaturePodA, FeaturePodA-FeaturePodAResources, FeaturePodAInterfaces, FeaturePodB, FeaturePodB-FeaturePodBResources, FeaturePodBInterfaces, HeadersObjcPod, HeadersPod, HeadersPodMappingDir, HeadersTest, HeadersTestMappingDir, IOSPod, InterimSinglePod, MultiPlatfromChildPod, MultiPod, MultiPodInterfaces, OrphanSinglePod, SinglePod, SinglePod-SinglePodSharedResources, SinglePod-SinglePodTVOSResources, SinglePod-SinglePodiOSResources, SinglePodDynamic, TVOSPod, TVOSPod-TVOSPodSharedResources")
//        XCTAssertStandardOutput(pattern: "All cacheable targets have been cached successfully as xcframeworks with simulator destination.")
//        XCTAssertStandardOutput(pattern: "Total time taken for swiftmodule cache fetch")
//
//        // Check the CocoapodsPod folder for the presence of the swiftmodule file and the absence of swiftinterface files
//        let binaryPodxcframeworkPath = fixturePath.appending(components: ["Geko", "Dependencies", "Cocoapods", "CocoapodsPod", "BinarySpec", "CocoapodsPod.xcframework"])
//        let iosBinaryPod = binaryPodxcframeworkPath.appending(components: ["ios-arm64_x86_64-simulator", "CocoapodsPod.framework", "Modules", "CocoapodsPod.swiftmodule"])
//        let tvosBinaryPod = binaryPodxcframeworkPath.appending(components: ["tvos-arm64_x86_64-simulator", "CocoapodsPod.framework", "Modules", "CocoapodsPod.swiftmodule"])
//
//        let paths = [iosBinaryPod, tvosBinaryPod]
//
//        for path in paths {
//            let contents = try FileHandler.shared.contentsOfDirectory(path)
//            XCTAssertTrue(contents.map { $0.pathString.contains(".swiftmodule")}.allSatisfy({$0}))
//            XCTAssertTrue(contents.map { !$0.pathString.contains(".swiftinterface")}.allSatisfy({$0}))
//        }
//
//        // Rebuild with same cache
//        // When
//        TestingLogHandler.reset()
//        try await run(GenerateCommand.self, arguments: [
//            "App",
//            "TVosApp",
//            "MultiPlatfromParentPod",
//            "--cache",
//            "--unsafe",
//            "--ignore-remote-cache",
//            "-P",
//            "all"
//        ])
//
//        // Then
//        XCTAssertStandardOutput(
//            pattern:
//            """
//            All cacheable targets are already cached
//            """
//        )
//    }
//}
