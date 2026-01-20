import Foundation
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
import XCTest
@testable import GekoCoreTesting
@testable import GekoLoader
@testable import GekoLoaderTesting
@testable import GekoSupportTesting

final class ConfigLoaderTests: GekoUnitTestCase {
    private var rootDirectoryLocator = MockRootDirectoryLocator()
    private var manifestLoader = MockManifestLoader()
    private var subject: ConfigLoader!
    private var registeredPaths: [AbsolutePath: Bool] = [:]
    private var registeredConfigs: [AbsolutePath: Result<ProjectDescription.Config, Error>] = [:]

    override func setUp() {
        super.setUp()
        subject = ConfigLoader(
            manifestLoader: manifestLoader,
            rootDirectoryLocator: rootDirectoryLocator,
            fileHandler: fileHandler
        )
        fileHandler.stubExists = { [weak self] path in
            self?.registeredPaths[path] == true
        }
        manifestLoader.loadConfigStub = { [weak self] path in
            guard let self,
                  let config = self.registeredConfigs[path]
            else {
                throw ManifestLoaderError.manifestNotFound(.config, path)
            }
            return try config.get()
        }
    }

    override func tearDown() {
        subject = nil
        manifestLoader.loadConfigStub = nil
        fileHandler.stubExists = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_loadConfig_defaultReturnedWhenPathDoesNotExist() throws {
        // Given
        let path: AbsolutePath = "/some/random/path"
        stub(path: path, exists: false)

        // When
        let result = try subject.loadConfig(path: path)

        // Then
        XCTAssertEqual(result, .default)
    }

    func test_loadConfig_loadConfig() throws {
        // Given
        let path: AbsolutePath = "/project/Geko/Config.swift"
        stub(path: path, exists: true)
        stub(
            config: .manifestTest(),
            at: path.parentDirectory
        )

        // When
        let result = try subject.loadConfig(path: path)

        // Then
        XCTAssertEqual(result, Config(
            compatibleXcodeVersions: .all,
            cloud: nil,
            cache: nil,
            swiftVersion: nil,
            plugins: [],
            generationOptions: .test(),
            preFetchScripts: [],
            preGenerateScripts: [],
            postGenerateScripts: [],
            cocoapodsUseBundler: false
        ))
    }

    func test_loadConfig_loadConfigError() throws {
        // Given
        let path: AbsolutePath = "/project/Geko/Config.swift"
        stub(path: path, exists: true)
        stub(configError: TestError.testError, at: "/project/Geko")

        // When / Then
        XCTAssertThrowsSpecific(try subject.loadConfig(path: path), TestError.testError)
    }

    func test_loadConfig_loadConfigInRootDirectory() throws {
        // Given
        stub(rootDirectory: "/project")
        let paths: [AbsolutePath] = [
            "/project/Geko/Config.swift",
            "/project/Module/",
            "/project/Module/A/",
        ]
        for item in paths {
            stub(path: item, exists: true)
        }
        stub(
            config: .manifestTest(),
            at: "/project/Geko"
        )

        // When
        let result = try subject.loadConfig(path: "/project/Module/A/")

        // Then
        XCTAssertEqual(result, Config(
            compatibleXcodeVersions: .all,
            cloud: nil,
            cache: nil,
            swiftVersion: nil,
            plugins: [],
            generationOptions: .test(),
            preFetchScripts: [],
            preGenerateScripts: [],
            postGenerateScripts: [],
            cocoapodsUseBundler: false
        ))
    }

    // MARK: - Helpers

    private func stub(path: AbsolutePath, exists: Bool) {
        registeredPaths[path] = exists
    }

    private func stub(configError: Error, at path: AbsolutePath) {
        registeredConfigs[path] = .failure(configError)
    }

    private func stub(config: ProjectDescription.Config, at path: AbsolutePath) {
        registeredConfigs[path] = .success(config)
    }

    private func stub(rootDirectory: AbsolutePath) {
        rootDirectoryLocator.locateStub = rootDirectory
    }

    private enum TestError: Error, Equatable {
        case testError
    }
}
