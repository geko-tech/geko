import Foundation
import ProjectDescription
import GekoAutomation
import GekoCore
import GekoGraph
import GekoLoader
import GekoSupport

enum TestServiceError: FatalError, Equatable {
    case schemeNotFound(scheme: String, existing: [String])
    case schemeWithoutTestableTargets(scheme: String, testPlan: String?)
    case testPlanNotFound(scheme: String, testPlan: String, existing: [String])
    case testIdentifierInvalid(value: String)
    case duplicatedTestTargets(Set<TestIdentifier>)
    case nothingToSkip(skipped: [TestIdentifier], included: [TestIdentifier])
    case actionInvalid
    case generateMetadataNotFound(path: String)
    case testTargetNotExist(target: String)
    case testTargetWasNotAddedToFocus(target: String)

    // Error description
    var description: String {
        switch self {
        case let .schemeNotFound(scheme, existing):
            return "Couldn't find scheme \(scheme). The available schemes are: \(existing.joined(separator: ", "))."
        case let .schemeWithoutTestableTargets(scheme, testPlan):
            let testPlanMessage: String
            if let testPlan, !testPlan.isEmpty {
                testPlanMessage = "test plan \(testPlan) in "
            } else {
                testPlanMessage = ""
            }
            return "The \(testPlanMessage)scheme \(scheme) cannot be built because it contains no buildable targets."
        case let .testPlanNotFound(scheme, testPlan, existing):
            let existingMessage: String
            if existing.isEmpty {
                existingMessage =
                    "We could not execute the test plan \(testPlan) because the scheme \(scheme) doesn't have test plans defined."
            } else {
                existingMessage =
                    "The test plan \(testPlan) in scheme \(scheme) doesn't exist. The following following test plans are defined: \(existing.joined(separator: ","))"
            }
            return "Couldn't find test plan \(testPlan) in scheme \(scheme). \(existingMessage)."
        case let .testIdentifierInvalid(value):
            return "Invalid test identifiers \(value). The expected format is TestTarget[/TestClass[/TestMethod]]."
        case let .duplicatedTestTargets(targets):
            return "The target identifier cannot be specified both in --test-targets and --skip-test-targets (were specified: \(targets.map(\.description).joined(separator: ", ")))"
        case let .nothingToSkip(skippedTargets, includedTargets):
            return "Some of the targets specified in --skip-test-targets (\(skippedTargets.map(\.description).joined(separator: ", "))) will always be skipped as they are not included in the targets specified (\(includedTargets.map(\.description).joined(separator: ", ")))"
        case .actionInvalid:
            return "Cannot specify both --build-only and --without-building"
        case let .generateMetadataNotFound(path):
            return "Couldn't find file 'generateMetadata.json'. You need to regenerate the project. Path - \(path)"
        case let .testTargetNotExist(target):
            return "Test target with name '\(target)' does not exist."
        case let .testTargetWasNotAddedToFocus(target):
            return "The test target '\(target)' exists in the project, but it was not added to the focus list when generating the project."
        }
    }

    // Error type
    var type: ErrorType {
        switch self {
        case .schemeNotFound, .schemeWithoutTestableTargets, .testPlanNotFound, .testIdentifierInvalid, .duplicatedTestTargets,
                .nothingToSkip, .actionInvalid, .generateMetadataNotFound, .testTargetNotExist, .testTargetWasNotAddedToFocus:
            return .abort
        }
    }
}

public final class TestService { // swiftlint:disable:this type_body_length
    private let generatorFactory: GeneratorFactorying
    private let xcodebuildController: XcodeBuildControlling
    private let buildGraphInspector: BuildGraphInspecting
    private let simulatorController: SimulatorControlling
    private let contentHasher: ContentHashing

    private let testsCacheTemporaryDirectory: TemporaryDirectory
    private let cacheDirectoryProviderFactory: CacheDirectoriesProviderFactoring
    private let logDirectoryProvider: LogDirectoriesProviding

    public convenience init(
        testsCacheTemporaryDirectory: TemporaryDirectory
    ) {
        self.init(
            testsCacheTemporaryDirectory: testsCacheTemporaryDirectory,
            generatorFactory: GeneratorFactory()
        )
    }

    convenience init() throws {
        let testsCacheTemporaryDirectory = try TemporaryDirectory(removeTreeOnDeinit: true)
        self.init(
            testsCacheTemporaryDirectory: testsCacheTemporaryDirectory
        )
    }

    init(
        testsCacheTemporaryDirectory: TemporaryDirectory,
        generatorFactory: GeneratorFactorying = GeneratorFactory(),
        xcodebuildController: XcodeBuildControlling = XcodeBuildController(),
        buildGraphInspector: BuildGraphInspecting = BuildGraphInspector(),
        simulatorController: SimulatorControlling = SimulatorController(),
        contentHasher: ContentHashing = ContentHasher(),
        cacheDirectoryProviderFactory: CacheDirectoriesProviderFactoring = CacheDirectoriesProviderFactory(),
        logDirectoryProvider: LogDirectoriesProviding = LogDirectoriesProvider(),
    ) {
        self.testsCacheTemporaryDirectory = testsCacheTemporaryDirectory
        self.generatorFactory = generatorFactory
        self.xcodebuildController = xcodebuildController
        self.buildGraphInspector = buildGraphInspector
        self.simulatorController = simulatorController
        self.contentHasher = contentHasher
        self.cacheDirectoryProviderFactory = cacheDirectoryProviderFactory
        self.logDirectoryProvider = logDirectoryProvider
    }

    public func validateParameters(
        testTargets: [TestIdentifier],
        skipTestTargets: [TestIdentifier]
    ) throws {
        let targetsIntersection = Set(testTargets)
            .intersection(skipTestTargets)
        if !targetsIntersection.isEmpty {
            throw TestServiceError.duplicatedTestTargets(targetsIntersection)
        }
        if !testTargets.isEmpty {
            // --test-targets Test --skip-test-targets AnotherTest
            let skipTestTargetsOnly = try Set(skipTestTargets.map { try TestIdentifier(target: $0.target) })
            let testTargetsOnly = try testTargets.map { try TestIdentifier(target: $0.target) }
            let targetsOnlyIntersection = skipTestTargetsOnly.intersection(testTargetsOnly)
            if !skipTestTargets.isEmpty, targetsOnlyIntersection.isEmpty {
                throw TestServiceError.nothingToSkip(
                    skipped: try skipTestTargets
                        .filter { skipTarget in try !testTargetsOnly.contains(TestIdentifier(target: skipTarget.target)) },
                    included: testTargets
                )
            }

            // --test-targets Test/MyClass --skip-test-targets Test/AnotherClass
            let skipTestTargetsClasses = try Set(skipTestTargets.map { try TestIdentifier(target: $0.target, class: $0.class) })
            let testTargetsClasses = try testTargets.lazy.filter { $0.class != nil }
                .map { try TestIdentifier(target: $0.target, class: $0.class) }
            let targetsClassesIntersection = skipTestTargetsClasses.intersection(testTargetsClasses)
            if !testTargetsClasses.isEmpty, !skipTestTargetsClasses.isEmpty, targetsClassesIntersection.isEmpty {
                throw TestServiceError.nothingToSkip(
                    skipped: try skipTestTargets
                        .filter { skipTarget in
                            try !testTargetsClasses
                                .contains { try $0 == TestIdentifier(target: skipTarget.target, class: skipTarget.class) }
                        },
                    included: testTargets
                )
            }

            // --test-targets Test/MyClass/MyMethod --skip-test-targets Test/MyClass/AnotherMethod
            let skipTestTargetsClassesMethods = Set(skipTestTargets)
            let testTargetsClassesMethods = testTargets.lazy.filter { $0.class != nil && $0.method != nil }
            let targetsClassesMethodsIntersection = skipTestTargetsClassesMethods.intersection(testTargetsClasses)
            if !testTargetsClassesMethods.isEmpty, targetsClassesMethodsIntersection.isEmpty,
               !skipTestTargetsClassesMethods.isEmpty
            {
                throw TestServiceError.nothingToSkip(skipped: skipTestTargets, included: testTargets)
            }
        }
    }

    // swiftlint:disable:next function_body_length
    public func run(
        schemeName: String?,
        generate: Bool,
        clean: Bool,
        configuration: String?,
        path: AbsolutePath,
        deviceName: String?,
        platform: String?,
        osVersion: String?,
        action: XcodeBuildTestAction,
        rosetta: Bool,
        skipUITests: Bool,
        resultBundlePath: AbsolutePath?,
        derivedDataPath: String?,
        retryCount: Int,
        testTargets: [TestIdentifier],
        skipTestTargets: [TestIdentifier],
        testPlanConfiguration: TestPlanConfiguration?,
        validateTestTargetsParameters: Bool = true,
        generator: Generating? = nil,
        generateOnly: Bool,
        passthroughXcodeBuildArguments: [String],
        editTestPlan: Bool,
    ) async throws {
        if validateTestTargetsParameters {
            try validateParameters(
                testTargets: testTargets,
                skipTestTargets: skipTestTargets
            )
        }
        // Load config
        let manifestLoaderFactory = ManifestLoaderFactory()
        let manifestLoader = manifestLoaderFactory.createManifestLoader()
        let configLoader = ConfigLoader(manifestLoader: manifestLoader)
        let config = try configLoader.loadConfig(path: path)

        let testGenerator: Generating
        if let generator {
            testGenerator = generator
        } else {
            testGenerator = try generatorFactory.test(
                config: config,
                testsCacheDirectory: testsCacheTemporaryDirectory.path,
                testPlan: testPlanConfiguration?.testPlan,
                includedTargets: Set(testTargets.map(\.target)),
                excludedTargets: Set(skipTestTargets.filter { $0.class == nil }.map(\.target)),
                skipUITests: skipUITests
            )
        }

        let graph: Graph

        if try (generate || buildGraphInspector.workspacePath(directory: path) == nil) {
            logger.notice("Generating project for testing", metadata: .section)
            graph = try await testGenerator.generateWithGraph(
                path: path
            ).1
        } else {
            graph = try await testGenerator.load(path: path)
        }

        if generateOnly {
            return
        }

        let graphTraverser = GraphTraverser(graph: graph)
        let version = osVersion?.version()
        let testableSchemes = buildGraphInspector.testableSchemes(graphTraverser: graphTraverser) +
            buildGraphInspector.workspaceSchemes(graphTraverser: graphTraverser)
        logger.log(
            level: .debug,
            "Found the following testable schemes: \(Set(testableSchemes.map(\.name)).joined(separator: ", "))"
        )

        let derivedDataPath = try derivedDataPath.map {
            try AbsolutePath(
                validating: $0,
                relativeTo: FileHandler.shared.currentPath
            )
        }

        let generateMetadata = try loadGenerateMetadata()

        if !testTargets.isEmpty {
            let allTestTargetsNames = graphTraverser.allInternalTargets()
                .filter(\.target.product.testsBundle)
                .map(\.target.name)

            for testTarget in testTargets {
                if !allTestTargetsNames.contains(testTarget.target) {
                    throw TestServiceError.testTargetNotExist(target: testTarget.target)
                }

                if generateMetadata.cacheEnabled && !generateMetadata.focusedTargets.contains(testTarget.target) {
                    throw TestServiceError.testTargetWasNotAddedToFocus(target: testTarget.target)
                }
            }
        }

        if let schemeName {
            guard let scheme = testableSchemes.first(where: { $0.name == schemeName })
            else {
                throw TestServiceError.schemeNotFound(
                    scheme: schemeName,
                    existing: testableSchemes.map(\.name)
                )
            }

            switch (testPlanConfiguration?.testPlan, scheme.testAction?.targets.isEmpty, scheme.testAction?.testPlans?.isEmpty) {
            case (_, false, _), (_, _, false):
                break
            case (nil, true, _), (nil, nil, _):
                logger.log(level: .info, "The scheme \(schemeName)'s test action has no tests to run, finishing early.")
                return
            case (_?, _, true), (_?, _, nil):
                logger.log(level: .info, "The scheme \(schemeName)'s test action has no test plans to run, finishing early.")
                return
            default:
                break
            }

            let testSchemes: [Scheme] = [scheme]

            for testScheme in testSchemes {
                try await self.testScheme(
                    scheme: testScheme,
                    graphTraverser: graphTraverser,
                    clean: clean,
                    configuration: configuration,
                    version: version,
                    deviceName: deviceName,
                    platform: platform,
                    action: action,
                    rosetta: rosetta,
                    resultBundlePath: resultBundlePath,
                    derivedDataPath: derivedDataPath,
                    retryCount: retryCount,
                    testTargets: testTargets,
                    skipTestTargets: skipTestTargets,
                    testPlanConfiguration: testPlanConfiguration,
                    passthroughXcodeBuildArguments: passthroughXcodeBuildArguments,
                    generateMetadata: generateMetadata,
                    editTestPlan: editTestPlan
                )
            }
        } else {
            let testSchemes: [Scheme] = buildGraphInspector.workspaceSchemes(graphTraverser: graphTraverser)
                .filter {
                    $0.testAction.map { !$0.targets.isEmpty } ?? false
                }

            if testSchemes.isEmpty {
                logger.log(level: .info, "There are no tests to run, finishing early")
                return
            }

            for testScheme in testSchemes {
                try await self.testScheme(
                    scheme: testScheme,
                    graphTraverser: graphTraverser,
                    clean: clean,
                    configuration: configuration,
                    version: version,
                    deviceName: deviceName,
                    platform: platform,
                    action: action,
                    rosetta: rosetta,
                    resultBundlePath: resultBundlePath,
                    derivedDataPath: derivedDataPath,
                    retryCount: retryCount,
                    testTargets: testTargets,
                    skipTestTargets: skipTestTargets,
                    testPlanConfiguration: testPlanConfiguration,
                    passthroughXcodeBuildArguments: passthroughXcodeBuildArguments,
                    generateMetadata: generateMetadata,
                    editTestPlan: editTestPlan
                )
            }
        }

        logger.log(level: .notice, "The project tests ran successfully", metadata: .success)
    }

    // MARK: - Helpers

    // swiftlint:disable:next function_body_length
    private func testScheme(
        scheme: Scheme,
        graphTraverser: GraphTraversing,
        clean: Bool,
        configuration: String?,
        version: Version?,
        deviceName: String?,
        platform: String?,
        action: XcodeBuildTestAction,
        rosetta: Bool,
        resultBundlePath: AbsolutePath?,
        derivedDataPath: AbsolutePath?,
        retryCount: Int,
        testTargets: [TestIdentifier],
        skipTestTargets: [TestIdentifier],
        testPlanConfiguration: TestPlanConfiguration?,
        passthroughXcodeBuildArguments: [String],
        generateMetadata: GenerateMetadata,
        editTestPlan: Bool
    ) async throws {
        logger.log(level: .notice, "Testing scheme \(scheme.name)", metadata: .section)

        if let testPlan = testPlanConfiguration?.testPlan, let testPlans = scheme.testAction?.testPlans {
            guard let foundedTestPlan = testPlans.first(where: { $0.name == testPlan }) else {
                throw TestServiceError.testPlanNotFound(
                    scheme: scheme.name,
                    testPlan: testPlan,
                    existing: testPlans.map(\.name)
                )
            }

            if editTestPlan {
                try processEditTestPlan(scheme: scheme, graphTraverser: graphTraverser, testTargets: testTargets, testPlan: foundedTestPlan, generateMetadata: generateMetadata)
            }
        }

        guard let buildableTarget = buildGraphInspector.testableTarget(
            scheme: scheme,
            testPlan: testPlanConfiguration?.testPlan,
            testTargets: testTargets,
            skipTestTargets: skipTestTargets,
            graphTraverser: graphTraverser,
            action: action
        ) else {
            throw TestServiceError.schemeWithoutTestableTargets(scheme: scheme.name, testPlan: testPlanConfiguration?.testPlan)
        }

        let buildPlatform: Platform

        if let platform, let inputPlatform = Platform(rawValue: platform) {
            buildPlatform = inputPlatform
        } else {
            buildPlatform = try buildableTarget.target.servicePlatform
        }

        let destination: XcodeBuildDestination?

        if passthroughXcodeBuildArguments.contains("-destination") {
            destination = nil
        } else {
            destination = try await XcodeBuildDestination.find(
                for: buildableTarget.target,
                on: buildPlatform,
                scheme: scheme,
                version: version,
                deviceName: deviceName,
                graphTraverser: graphTraverser,
                simulatorController: simulatorController
            )
        }

        try xcodebuildController.test(
            .workspace(graphTraverser.workspace.xcWorkspacePath),
            scheme: scheme.name,
            clean: clean,
            destination: destination,
            action: action,
            rosetta: rosetta,
            derivedDataPath: derivedDataPath,
            resultBundlePath: resultBundlePath,
            arguments: buildGraphInspector.buildArguments(
                project: buildableTarget.project,
                target: buildableTarget.target,
                configuration: configuration,
                skipSigning: false
            ),
            retryCount: retryCount,
            testTargets: testTargets,
            skipTestTargets: skipTestTargets,
            testPlanConfiguration: testPlanConfiguration,
            passthroughXcodeBuildArguments: passthroughXcodeBuildArguments
        )
    }

    private func loadGenerateMetadata() throws -> GenerateMetadata {
        let generateMetadataPath = try logDirectoryProvider
            .logDirectory(for: .generateMetadata)
            .appending(component: Constants.GekoUserCacheDirectory.generateMetadataName)

        if !FileHandler.shared.exists(generateMetadataPath) {
            throw TestServiceError.generateMetadataNotFound(path: generateMetadataPath.pathString)
        }

        return try JSONRepository<GenerateMetadata>(url: generateMetadataPath.asURL).fetch()
    }

    private func processEditTestPlan(
        scheme: Scheme,
        graphTraverser: GraphTraversing,
        testTargets: [TestIdentifier],
        testPlan: TestPlan,
        generateMetadata: GenerateMetadata
    ) throws {
        let autogeneratedXCTestPlanRepo = JSONRepository<AutogeneratedXCTestPlan>(url: testPlan.path.asURL)
        var autogeneratedXCTestPlan = try autogeneratedXCTestPlanRepo.fetch()

        if testTargets.isEmpty {
            autogeneratedXCTestPlan.testTargets = generateMetadata.allTestTargets
        } else {
            autogeneratedXCTestPlan.testTargets = generateMetadata.allTestTargets.filter { availableTestTarget in
                testTargets.contains { $0.target == availableTestTarget.target.name }
            }
        }

        try autogeneratedXCTestPlanRepo.save(autogeneratedXCTestPlan)
    }
}
