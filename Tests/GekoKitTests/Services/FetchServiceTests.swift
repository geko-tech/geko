import GekoDependencies
import GekoDependenciesTesting
import GekoGraph
import GekoLoader
import GekoSupport
import GekoPluginTesting
import GekoLoaderTesting
import ProjectDescription
import XCTest

@testable import GekoKit
@testable import GekoSupportTesting

final class FetchServiceTests: GekoUnitTestCase {
    private var pluginsFacade: MockPluginsFacade!
    private var configLoader: MockConfigLoader!
    private var manifestLoader: MockManifestLoader!
    private var dependenciesController: MockDependenciesController!
    private var packageSettingsLoader: MockPackageSettingsLoader!
    private var dependenciesModelLoader: MockDependenciesModelLoader!

    private var subject: FetchService!

    override func setUp() {
        super.setUp()

        pluginsFacade = MockPluginsFacade()
        configLoader = MockConfigLoader()
        manifestLoader = MockManifestLoader()
        manifestLoader.manifestsAtStub = { _ in [.project] }
        dependenciesController = MockDependenciesController()
        dependenciesModelLoader = MockDependenciesModelLoader()
        packageSettingsLoader = MockPackageSettingsLoader()

        subject = FetchService(
            pluginsFacade: pluginsFacade,
            configLoader: configLoader,
            manifestLoader: manifestLoader,
            dependenciesController: dependenciesController,
            dependenciesModelLoader: dependenciesModelLoader,
            packageSettingsLoader: packageSettingsLoader
        )
    }

    override func tearDown() {
        subject = nil

        pluginsFacade = nil
        configLoader = nil
        dependenciesController = nil
        dependenciesModelLoader = nil

        super.tearDown()
    }
    
    func test_run_when_fetch_needed_for_cocoapods_dependencies() async throws {
        // Given
        let stubbedNeedCache = false
        let stubbedPath = try temporaryPath()
        let stubbedDependencies = Dependencies(cocoapods: CocoapodsDependencies(repos: ["https://cdn.cocoapods.org"], dependencies: [.cdn(name: "A", requirement: .exact("1.0.0"), source: "https://cdn.cocoapods.org")]))

        dependenciesModelLoader.loadDependenciesStub = { _, _ in
            stubbedDependencies
        }
        dependenciesController.needFetchStub = { cocoapodsDependencies, packageSettings, path, cache in
            XCTAssertEqual(cocoapodsDependencies, stubbedDependencies.cocoapods)
            XCTAssertNil(packageSettings)
            XCTAssertEqual(path, stubbedPath)
            XCTAssertEqual(cache, stubbedNeedCache)
            return true
        }
        
        try fileHandler.touch(
            stubbedPath.appending(
                components: Constants.gekoDirectoryName, Manifest.dependencies.fileName(stubbedPath)
            )
        )
        
        // When
        let result = try await subject.needFetch(path: stubbedPath.pathString, cache: stubbedNeedCache)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(dependenciesController.invokedNeedFetch)
        XCTAssertTrue(dependenciesModelLoader.invokedLoadDependencies)
    }
    
    func test_run_when_fetch_needed_for_package_dependencies() async throws {
        // Given
        let stubbedNeedCache = false
        let stubbedPath = try temporaryPath()
        let stubbedPackageSettings = PackageSettings()
        packageSettingsLoader.loadPackageSettingsStub = { _, _ in stubbedPackageSettings }
        dependenciesController.needFetchStub = { cocoapodsDependencies, packageSettings, path, cache in
            XCTAssertEqual(packageSettings, stubbedPackageSettings)
            XCTAssertNil(cocoapodsDependencies)
            XCTAssertEqual(path, stubbedPath)
            XCTAssertEqual(cache, stubbedNeedCache)
            return true
        }
        
        try fileHandler.touch(
            stubbedPath.appending(
                components: Constants.gekoDirectoryName, Manifest.package.fileName(stubbedPath)
            )
        )
        
        // When
        let result = try await subject.needFetch(path: stubbedPath.pathString, cache: stubbedNeedCache)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(dependenciesController.invokedNeedFetch)
        XCTAssertTrue(packageSettingsLoader.invokedLoadPackageSettings)
    }
    
    func test_run_when_fetch_no_needed() async throws {
        // Given
        let stubbedNeedCache = false
        let stubbedPath = try temporaryPath()

        // When
        let result = try await subject.needFetch(path: stubbedPath.pathString, cache: stubbedNeedCache)
        
        // Then
        XCTAssertFalse(result)
    }

    func test_run_when_updating_cocoapods_dependencies() async throws {
        // Given
        let stubbedPath = try temporaryPath()
        let stubbedDependencies = Dependencies(cocoapods: CocoapodsDependencies(repos: ["https://cdn.cocoapods.org"], dependencies: [.cdn(name: "A", requirement: .exact("1.0.0"), source: "https://cdn.cocoapods.org")]))
        dependenciesModelLoader.loadDependenciesStub = { _, _ in stubbedDependencies }

        let stubbedConfig = Config.test(
            plugins: [
                .git(url: "url", tag: "tag")
            ]
        )
        
        configLoader.loadConfigStub = { _ in
            stubbedConfig
        }

        dependenciesController.updateStub = { path, config, _, cocoapods, packageSettings in
            XCTAssertEqual(path, stubbedPath)
            XCTAssertEqual(config, stubbedConfig)
            XCTAssertEqual(cocoapods, stubbedDependencies.cocoapods)
            return .none
        }
        dependenciesController.saveStub = { dependenciesGraph, path in
            XCTAssertEqual(dependenciesGraph, .none)
            XCTAssertEqual(path, stubbedPath)
        }
        pluginsFacade.fetchRemotePluginsStub = { _ in
            _ = Plugins.test()
        }

        try fileHandler.touch(
            stubbedPath.appending(
                components: Constants.gekoDirectoryName, Manifest.dependencies.fileName(stubbedPath)
            )
        )

        // When
        try await subject.run(
            path: stubbedPath.pathString,
            update: true,
            repoUpdate: false,
            deployment: false,
            passthroughArguments: []
        )

        // Then
        XCTAssertTrue(dependenciesController.invokedUpdate)
        XCTAssertTrue(dependenciesModelLoader.invokedLoadDependencies)
        XCTAssertTrue(dependenciesController.invokedSave)

        XCTAssertFalse(dependenciesController.invokedFetch)
    }
    
    func test_run_when_updating_package_dependencies() async throws {
        // Given
        let stubbedPath = try temporaryPath()
        
        let stubbedPackageSettings = PackageSettings()
        packageSettingsLoader.loadPackageSettingsStub = { _, _ in stubbedPackageSettings }
        
        let stubbedPassthroughArguments = ["--replace-scm-with-registry"]

        let stubbedConfig = Config.test(
            plugins: [
                .git(url: "url", tag: "tag")
            ]
        )
        
        configLoader.loadConfigStub = { _ in
            stubbedConfig
        }
        
        dependenciesController.updateStub = { path, config, passthroughArguments, cocoapods, packageSettings in
            XCTAssertEqual(path, stubbedPath)
            XCTAssertEqual(config, stubbedConfig)
            XCTAssertEqual(passthroughArguments, stubbedPassthroughArguments)
            XCTAssertEqual(packageSettings, stubbedPackageSettings)
            return .none
        }
        dependenciesController.saveStub = { dependenciesGraph, path in
            XCTAssertEqual(dependenciesGraph, .none)
            XCTAssertEqual(path, stubbedPath)
        }
        pluginsFacade.fetchRemotePluginsStub = { _ in
            _ = Plugins.test()
        }

        try fileHandler.touch(
            stubbedPath.appending(
                components: Constants.gekoDirectoryName, Manifest.package.fileName(stubbedPath)
            )
        )

        // When
        try await subject.run(
            path: stubbedPath.pathString,
            update: true,
            repoUpdate: false,
            deployment: false,
            passthroughArguments: stubbedPassthroughArguments
        )

        // Then
        XCTAssertTrue(dependenciesController.invokedUpdate)
        XCTAssertTrue(packageSettingsLoader.invokedLoadPackageSettings)
        XCTAssertTrue(dependenciesController.invokedSave)

        XCTAssertFalse(dependenciesController.invokedFetch)
    }

    func test_run_when_fetching_plugins() async throws {
        // Given
        let config = Config.test(
            plugins: [
                .git(url: "url", tag: "tag")
            ]
        )
        configLoader.loadConfigStub = { _ in
            config
        }
        var invokedConfig: Config?
        pluginsFacade.loadPluginsStub = { config in
            invokedConfig = config
            return .test()
        }

        // When
        try await subject.run(
            path: nil,
            update: false,
            repoUpdate: false,
            deployment: false,
            passthroughArguments: []
        )

        // Then
        XCTAssertEqual(invokedConfig, config)
    }

    func test_run_when_fetching_cocoapods_dependencies() async throws {
        // Given
        let stubbedPath = try temporaryPath()
        let stubbedRepoUpdate = false
        let stubbedDeployment = false
        let stubbedDependencies = Dependencies(cocoapods: CocoapodsDependencies(repos: ["https://cdn.cocoapods.org"], dependencies: [.cdn(name: "A", requirement: .exact("1.0.0"), source: "https://cdn.cocoapods.org")]))
        dependenciesModelLoader.loadDependenciesStub = { _, _ in stubbedDependencies }

        let stubbedConfig = Config.test(
            plugins: [
                .git(url: "url", tag: "tag")
            ]
        )
        
        configLoader.loadConfigStub = { _ in
            stubbedConfig
        }
        dependenciesController.fetchStub = { path, config, arguments, cocoapodsDeps, packageSettings, repoUpdate, deployment in
            XCTAssertEqual(path, stubbedPath)
            XCTAssertEqual(config, stubbedConfig)
            XCTAssertEqual(cocoapodsDeps, stubbedDependencies.cocoapods)
            XCTAssertEqual(repoUpdate, stubbedRepoUpdate)
            XCTAssertEqual(deployment, stubbedDeployment)
            return .none
        }
        dependenciesController.saveStub = { dependenciesGraph, path in
            XCTAssertEqual(dependenciesGraph, .none)
            XCTAssertEqual(path, stubbedPath)
        }
        pluginsFacade.fetchRemotePluginsStub = { _ in }

        try fileHandler.touch(
            stubbedPath.appending(
                components: Constants.gekoDirectoryName, Manifest.dependencies.fileName(stubbedPath)
            )
        )

        // When
        try await subject.run(
            path: stubbedPath.pathString,
            update: false,
            repoUpdate: stubbedRepoUpdate,
            deployment: stubbedDeployment,
            passthroughArguments: []
        )

        // Then
        XCTAssertTrue(dependenciesModelLoader.invokedLoadDependencies)
        XCTAssertTrue(dependenciesController.invokedFetch)
        XCTAssertTrue(dependenciesController.invokedSave)

        XCTAssertFalse(dependenciesController.invokedUpdate)
    }
    
    func test_run_when_fetching_package_dependencies() async throws {
        // Given
        let stubbedPath = try temporaryPath()
        let stubbedRepoUpdate = false
        let stubbedDeployment = false
        
        let stubbedPackageSettings = PackageSettings()
        packageSettingsLoader.loadPackageSettingsStub = { _, _ in stubbedPackageSettings }
        
        let stubbedPassthroughArguments = ["--replace-scm-with-registry"]

        let stubbedConfig = Config.test(
            plugins: [
                .git(url: "url", tag: "tag")
            ]
        )
        
        configLoader.loadConfigStub = { _ in
            stubbedConfig
        }

        dependenciesController.fetchStub = { path, config, passthroughArguments, cocoapodsDeps, packageSettings, repoUpdate, deployment in
            XCTAssertEqual(path, stubbedPath)
            XCTAssertEqual(config, stubbedConfig)
            XCTAssertEqual(passthroughArguments, stubbedPassthroughArguments)
            XCTAssertEqual(packageSettings, stubbedPackageSettings)
            return .none
        }
        dependenciesController.saveStub = { dependenciesGraph, path in
            XCTAssertEqual(dependenciesGraph, .none)
            XCTAssertEqual(path, stubbedPath)
        }
        pluginsFacade.fetchRemotePluginsStub = { _ in }

        try fileHandler.touch(
            stubbedPath.appending(
                components: Constants.gekoDirectoryName, Manifest.package.fileName(stubbedPath)
            )
        )

        // When
        try await subject.run(
            path: stubbedPath.pathString,
            update: false,
            repoUpdate: stubbedRepoUpdate,
            deployment: stubbedDeployment,
            passthroughArguments: stubbedPassthroughArguments
        )

        // Then
        XCTAssertTrue(packageSettingsLoader.invokedLoadPackageSettings)
        XCTAssertTrue(dependenciesController.invokedFetch)
        XCTAssertTrue(dependenciesController.invokedSave)

        XCTAssertFalse(dependenciesController.invokedUpdate)
    }

    func test_fetch_when_from_a_geko_project_directory() async throws {
        // Given
        let exp = expectation(description: "awaiting path validation")
        let temporaryDirectory = try temporaryPath()
        let expectedFoundDependenciesLocation = temporaryDirectory.appending(
            components: Constants.gekoDirectoryName, Manifest.dependencies.fileName(temporaryDirectory)
        )
        let stubbedDependencies = Dependencies(
            cocoapods: nil
        )

        // When looking for the Dependencies.swift file the model loader will search in the given path
        // This is where we will assert
        dependenciesModelLoader.loadDependenciesStub = { path, _ in
            defer { exp.fulfill() }
            XCTAssertEqual(temporaryDirectory, path)
            return stubbedDependencies
        }

        // Dependencies.swift in root
        try fileHandler.touch(expectedFoundDependenciesLocation)

        // When - This will cause the `loadDependenciesStub` closure to be called and assert if needed
        try await subject.run(
            path: temporaryDirectory.pathString,
            update: false,
            repoUpdate: false,
            deployment: false,
            passthroughArguments: []
        )
        await fulfillment(of: [exp], timeout: 0.1)
    }

    func test_fetch_path_is_found_in_geko_project_directory_but_manifest_is_in_nested_directory() async throws {
        // Given
        let exp = expectation(description: "awaiting path validation")
        let temporaryDirectory = try temporaryPath()
        let expectedFoundDependenciesLocation = temporaryDirectory.appending(
            components: Constants.gekoDirectoryName, Manifest.dependencies.fileName(temporaryDirectory)
        )
        let stubbedDependencies = Dependencies(
            cocoapods: nil
        )

        // When looking for the Dependencies.swift file the model loader will search in the given path
        // This is where we will assert
        dependenciesModelLoader.loadDependenciesStub = { path, _ in
            defer { exp.fulfill() }
            XCTAssertEqual(temporaryDirectory, path)
            return stubbedDependencies
        }

        // Dependencies.swift in root
        try fileHandler.touch(expectedFoundDependenciesLocation)

        // When - This will cause the `loadDependenciesStub` closure to be called and assert if needed
        try await subject.run(
            path: temporaryDirectory.pathString,
            update: false,
            repoUpdate: false,
            deployment: false,
            passthroughArguments: []
        )
        await fulfillment(of: [exp], timeout: 0.1)
    }

    func test_fetch_path_is_found_in_nested_manifest_directory() async throws {
        // Given
        let exp = expectation(description: "awaiting path validation")
        let temporaryDirectory = try temporaryPath()
        let manifestPath = temporaryDirectory
            .appending(components: ["First", "Second"])
        let expectedFoundDependenciesLocation = manifestPath.appending(
            components: Constants.gekoDirectoryName, Manifest.dependencies.fileName(temporaryDirectory)
        )
        let stubbedDependencies = Dependencies(
            cocoapods: nil
        )

        // When looking for the Dependencies.swift file the model loader will search in the given path
        // This is where we will assert
        dependenciesModelLoader.loadDependenciesStub = { path, _ in
            defer { exp.fulfill() }
            XCTAssertEqual(manifestPath, path)
            return stubbedDependencies
        }

        // Dependencies.swift in root
        try fileHandler.touch(expectedFoundDependenciesLocation)

        // When - This will cause the `loadDependenciesStub` closure to be called and assert if needed
        try await subject.run(
            path: manifestPath.pathString,
            update: false,
            repoUpdate: false,
            deployment: false,
            passthroughArguments: []
        )
        await fulfillment(of: [exp], timeout: 0.1)
    }
}
