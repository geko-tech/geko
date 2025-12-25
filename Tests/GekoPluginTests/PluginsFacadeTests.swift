import ProjectDescription
import GekoCore
import GekoCoreTesting
import GekoGraph
import GekoGraphTesting
import GekoLoader
import GekoLoaderTesting
import GekoScaffold
import GekoScaffoldTesting
import GekoSupport
import GekoSupportTesting
import XCTest
import GekoPluginTesting

@testable import GekoPlugin

private extension String {
    static let pluginName = "AwesomePlugin"
    static let baseUrl = "https://baseurl.org"
    static let executableName = "executable1"
    static let pluginUrl = "https://url/to/archive.zip"
}

final class PluginsFacadeTests: GekoUnitTestCase {
    private var manifestLoader: MockManifestLoader!
    private var templatesDirectoryLocator: MockTemplatesDirectoryLocator!
    private var gitHandler: MockGitHandler!
    private var subject: PluginsFacade!
    private var rootDirectoryLocator: MockRootDirectoryLocator!
    private var mockCachePath: AbsolutePath!
    private var pluginArchiveDownloader: MockPluginArchiveDownloader!
    private var pluginCacheDirectory: AbsolutePath!

    override func setUp() {
        super.setUp()
        manifestLoader = MockManifestLoader()
        templatesDirectoryLocator = MockTemplatesDirectoryLocator()
        gitHandler = MockGitHandler()
        mockCachePath = try! temporaryPath().appending(components: [Constants.GekoUserCacheDirectory.name, CacheCategory.plugins.directoryName])
        pluginCacheDirectory = mockCachePath
            .appending(component: .pluginName)

        rootDirectoryLocator = MockRootDirectoryLocator()
        pluginArchiveDownloader = MockPluginArchiveDownloader()
        subject = PluginsFacade(
            manifestLoader: manifestLoader,
            templatesDirectoryLocator: templatesDirectoryLocator,
            fileHandler: fileHandler,
            gitHandler: gitHandler,
            rootDirectoryLocator: rootDirectoryLocator,
            pluginArchiveDownloader: pluginArchiveDownloader
        )
    }

    override func tearDown() {
        manifestLoader = nil
        templatesDirectoryLocator = nil
        gitHandler = nil
        rootDirectoryLocator = nil
        subject = nil
        mockCachePath = nil
        pluginArchiveDownloader = nil
        super.tearDown()
    }

    func test_fetch_remote_plugin_with_custom_manifest_executable_not_found() async throws {
        // given
        let config = mockConfig(plugins: [
            .remote(
                url: .pluginUrl,
                manifest: .plugin(
                    name: .pluginName,
                    executables: [ExecutablePlugin(name: "not_existing_executable")]
                )
            )
        ])
        fileHandler.stubExists = { path in
            false
        }

        // when & then
        await XCTAssertThrowsSpecific(
            _ = try await subject.fetchRemotePlugins(using: config),
            PluginsFacadeError.executableNotFound(
                pluginName: .pluginName,
                executableName: "not_existing_executable",
                path: nil
            )
        )
    }

    func test_fetch_remote_plugin_with_custom_manifest_executable() async throws {
        // given
        let config = mockConfig(plugins: [
            .remote(
                url: .pluginUrl,
                manifest: .plugin(
                    name: .pluginName,
                    executables: [ExecutablePlugin(name: .executableName)]
                )
            )
        ])
        let executableOnePath = pluginCacheDirectory
            .appending(component: .executableName)

        fileHandler.stubExists = { path in
            if path == executableOnePath {
                true
            } else {
                false
            }
        }

        // when
        _ = try await subject.fetchRemotePlugins(using: config)

        // then
        XCTAssertEqual(
            pluginArchiveDownloader.invokedDownloadParameters?.pluginCacheDirectory,
            pluginCacheDirectory
        )
        XCTAssertEqual(
            pluginArchiveDownloader.invokedDownloadParameters?.url,
            .pluginUrl
        )
        XCTAssertEqual(system.invokedChmodParameters?.mode, .executable)
        XCTAssertEqual(system.invokedChmodParameters?.path, executableOnePath)
        XCTAssertEqual(system.invokedChmodParameters?.options, [.onlyFiles])
    }

    func test_fetch_remote_plugin_with_custom_manifest_executable_with_custom_path() async throws {
        // given
        let customPath = "bin"
        let config = mockConfig(plugins: [
            .remote(
                url: .pluginUrl,
                manifest: .plugin(
                    name: .pluginName,
                    executables: [
                        ExecutablePlugin(name: .executableName, path: customPath)
                    ]
                )
            )
        ])
        let executableOnePath = pluginCacheDirectory
            .appending(component: customPath)
            .appending(component: .executableName)

        fileHandler.stubExists = { path in
            if path == executableOnePath {
                true
            } else {
                false
            }
        }

        // when
        _ = try await subject.fetchRemotePlugins(using: config)

        // then
        XCTAssertEqual(system.invokedChmodParameters?.mode, .executable)
        XCTAssertEqual(system.invokedChmodParameters?.path, executableOnePath)
        XCTAssertEqual(system.invokedChmodParameters?.options, [.onlyFiles])
    }

    func test_remote_plugin_with_custom_manifest_executable_paths() async throws {
        // given
        let config = mockConfig(plugins: [
            .remote(
                url: .pluginUrl,
                manifest: .plugin(
                    name: .pluginName,
                    executables: [
                        ExecutablePlugin(name: .executableName)
                    ]
                )
            )
        ])
        let executableOnePath = pluginCacheDirectory
            .appending(component: .executableName)

        fileHandler.stubExists = { path in
            true
        }

        // when
        let executablePlugins = try subject.executablePlugins(using: config)

        // then
        XCTAssertEqual(executablePlugins.count, 1)
        let executablePlugin = executablePlugins[0]
        XCTAssertEqual(executablePlugin.name, .pluginName)
        XCTAssertEqual(executablePlugin.executablePaths.count, 1)
        XCTAssertEqual(executablePlugin.executablePaths[0].name, .executableName)
        XCTAssertEqual(executablePlugin.executablePaths[0].path, executableOnePath)
    }

    func test_remote_plugin_with_custom_manifest_executable_paths_with_custom_path() async throws {
        // given
        let customPath = "bin"
        let config = mockConfig(plugins: [
            .remote(
                url: .pluginUrl,
                manifest: .plugin(
                    name: .pluginName,
                    executables: [
                        ExecutablePlugin(name: .executableName, path: customPath)
                    ]
                )
            )
        ])
        let executableOnePath = pluginCacheDirectory
            .appending(component: customPath)
            .appending(component: .executableName)

        fileHandler.stubExists = { path in
            false
        }

        // when
        let executablePlugins = try subject.executablePlugins(using: config)

        // then
        XCTAssertEqual(executablePlugins.count, 1)
        let executablePlugin = executablePlugins[0]
        XCTAssertEqual(executablePlugin.name, .pluginName)
        XCTAssertEqual(executablePlugin.executablePaths.count, 1)
        XCTAssertEqual(executablePlugin.executablePaths[0].name, .executableName)
        XCTAssertEqual(executablePlugin.executablePaths[0].path, executableOnePath)
    }

    func test_fetch_remote_geko_archive() async throws {
        // given
        let expectedGekoArchiveUrl = "https://baseurl.org/AwesomePlugin/1.0.0/AwesomePlugin.macos.geko-plugin.zip"
        let config = mockConfig(plugins: [
            .remote(baseUrl: .baseUrl, name: .pluginName, version: "1.0.0")
        ])
        manifestLoader.loadPluginStub = { _ in
            Plugin(name: .pluginName, executables: [ExecutablePlugin(name: .executableName)])
        }

        let executableOnePath = pluginCacheDirectory
            .appending(component: .executableName)

        fileHandler.stubExists = { path in
            if path == executableOnePath {
                true
            } else {
                false
            }
        }

        // when
        _ = try await subject.fetchRemotePlugins(using: config)

        // then
        XCTAssertEqual(
            pluginArchiveDownloader.invokedDownloadParameters?.pluginCacheDirectory,
            pluginCacheDirectory
        )
        XCTAssertEqual(
            pluginArchiveDownloader.invokedDownloadParameters?.url,
            expectedGekoArchiveUrl
        )
        XCTAssertEqual(system.invokedChmodParameters?.mode, .executable)
        XCTAssertEqual(system.invokedChmodParameters?.path, executableOnePath)
        XCTAssertEqual(system.invokedChmodParameters?.options, [.onlyFiles])
    }

    func test_remote_geko_archive_executable_paths() async throws {
        // given
        let config = mockConfig(plugins: [
            .remote(baseUrl: .baseUrl, name: .pluginName, version: "1.0.0")
        ])
        manifestLoader.loadPluginStub = { _ in
            Plugin(name: .pluginName, executables: [ExecutablePlugin(name: .executableName)])
        }

        let executableOnePath = pluginCacheDirectory
            .appending(component: .executableName)

        fileHandler.stubExists = { path in
            true
        }

        // when
        let executablePlugins = try subject.executablePlugins(using: config)

        // then
        XCTAssertEqual(executablePlugins.count, 1)
        let executablePlugin = executablePlugins[0]
        XCTAssertEqual(executablePlugin.name, .pluginName)
        XCTAssertEqual(executablePlugin.executablePaths.count, 1)
        XCTAssertEqual(executablePlugin.executablePaths[0].name, .executableName)
        XCTAssertEqual(executablePlugin.executablePaths[0].path, executableOnePath)
    }

    func test_remote_geko_archive_workspace_mapper_paths() async throws {
        // given
        let workspaceMapperName = "AwesomeWorkspaceMapper"
        let config = mockConfig(plugins: [
            .remote(baseUrl: .baseUrl, name: .pluginName, version: "1.0.0")
        ])
        manifestLoader.loadPluginStub = { _ in
            Plugin(name: .pluginName, workspaceMapper: WorkspaceMapperPlugin(name: workspaceMapperName))
        }

        let workspaceMapperPath = pluginCacheDirectory
            .appending(component: Constants.Plugins.mappers)
            .appending(component: "\(workspaceMapperName).framework")
            .appending(component: workspaceMapperName)

        fileHandler.stubExists = { path in
            true
        }

        fileHandler.stubReadFile = { _ in
            """
            {
                "projectDescriptionVersion": "release/0.5.1"
            }
            """.data(using: .utf8)!
        }

        // when
        let workspaceMapperPlugins = try subject.workspaceMapperPlugins(using: config)

        // then
        XCTAssertEqual(workspaceMapperPlugins.count, 1)
        let workspaceMapperPlugin = workspaceMapperPlugins[0]
        XCTAssertEqual(workspaceMapperPlugin.name, .pluginName)
        XCTAssertEqual(workspaceMapperPlugin.path, workspaceMapperPath)
        XCTAssertEqual(workspaceMapperPlugin.info.projectDescriptionVersion, "release/0.5.1")
    }

    func test_remote_geko_archive_cached() async throws {
        // given
        let expectedGekoArchiveUrl = "https://baseurl.org/AwesomePlugin/1.0.0/AwesomePlugin.macos.geko-plugin.zip"
        let config = mockConfig(plugins: [
            .remote(baseUrl: .baseUrl, name: .pluginName, version: "1.0.0")
        ])
        manifestLoader.loadPluginStub = { _ in
            Plugin(name: .pluginName, executables: [ExecutablePlugin(name: .executableName)])
        }

        let executableOnePath = pluginCacheDirectory
            .appending(component: .executableName)

        fileHandler.stubExists = { path in
            true
        }

        fileHandler.stubReadFile = { _ in
            """
            pluginsMetadata:
            - hash: \(expectedGekoArchiveUrl.md5)
              name: \(String.pluginName)
              url: \(expectedGekoArchiveUrl)
            """.data(using: .utf8)!
        }

        // when
        _ = try await subject.loadPlugins(using: config)
        let executablePlugins = try subject.executablePlugins(using: config)

        // then
        XCTAssertNil(pluginArchiveDownloader.invokedDownloadParameters)

        XCTAssertEqual(executablePlugins.count, 1)
        let executablePlugin = executablePlugins[0]
        XCTAssertEqual(executablePlugin.name, .pluginName)
        XCTAssertEqual(executablePlugin.executablePaths.count, 1)
        XCTAssertEqual(executablePlugin.executablePaths[0].name, .executableName)
        XCTAssertEqual(executablePlugin.executablePaths[0].path, executableOnePath)
    }

    func test_fetchRemotePlugins_when_git_sha() async throws {
        // Given
        let pluginGitURL = "https://url/to/repo.git"
        let pluginGitSha = "abc"
        let pluginFingerprint = "\(pluginGitURL)-\(pluginGitSha)".md5
        let config = mockConfig(
            plugins: [
                .git(url: pluginGitURL, sha: pluginGitSha, directory: nil),
            ]
        )
        var invokedCloneURL: String?
        var invokedClonePath: AbsolutePath?
        gitHandler.cloneToStub = { url, path in
            invokedCloneURL = url
            invokedClonePath = path
        }
        var invokedCheckoutID: String?
        var invokedCheckoutPath: AbsolutePath?
        gitHandler.checkoutStub = { id, path in
            invokedCheckoutID = id
            invokedCheckoutPath = path
        }

        // When
        _ = try await subject.fetchRemotePlugins(using: config)

        // Then
        XCTAssertEqual(invokedCloneURL, pluginGitURL)
        XCTAssertEqual(
            invokedClonePath,
            mockCachePath.appending(component: pluginFingerprint)
        )
        XCTAssertEqual(invokedCheckoutID, pluginGitSha)
        XCTAssertEqual(
            invokedCheckoutPath,
            mockCachePath.appending(component: pluginFingerprint)
        )
    }

    func test_fetchRemotePlugins_when_git_tag_and_repository_not_cached() async throws {
        // Given
        let pluginGitURL = "https://url/to/repo.git"
        let pluginGitTag = "1.0.0"
        let pluginFingerprint = "\(pluginGitURL)-\(pluginGitTag)".md5
        let config = mockConfig(
            plugins: [
                .git(url: pluginGitURL, tag: pluginGitTag, directory: nil),
            ]
        )
        var invokedCloneURL: String?
        var invokedClonePath: AbsolutePath?
        gitHandler.cloneToStub = { url, path in
            invokedCloneURL = url
            invokedClonePath = path
        }
        var invokedCheckoutID: String?
        var invokedCheckoutPath: AbsolutePath?
        gitHandler.checkoutStub = { id, path in
            invokedCheckoutID = id
            invokedCheckoutPath = path
        }

        // When
        _ = try await subject.fetchRemotePlugins(using: config)

        // Then
        XCTAssertEqual(invokedCloneURL, pluginGitURL)
        XCTAssertEqual(
            invokedClonePath,
            mockCachePath.appending(component: pluginFingerprint)
        )
        XCTAssertEqual(invokedCheckoutID, pluginGitTag)
        XCTAssertEqual(
            invokedCheckoutPath,
            mockCachePath.appending(component: pluginFingerprint)
        )
    }

    func test_fetchRemotePlugins_when_git_tag_and_repository_cached() async throws {
        // Given
        let pluginGitURL = "https://url/to/repo.git"
        let pluginGitTag = "1.0.0"
        let pluginFingerprint = "\(pluginGitURL)-\(pluginGitTag)".md5
        let config = mockConfig(
            plugins: [
                .git(url: pluginGitURL, tag: pluginGitTag, directory: nil),
            ]
        )

        let pluginDirectory = mockCachePath.appending(component: pluginFingerprint)
        try fileHandler.touch(
            pluginDirectory
                .appending(components: Constants.DependenciesDirectory.packageSwiftName)
        )
        let commandPath = pluginDirectory.appending(components: Constants.Plugins.executables, "geko-command")
        try fileHandler.touch(commandPath)

        // When / Then
        _ = try await subject.fetchRemotePlugins(using: config)
    }

    func test_loadPlugins_WHEN_localHelpers() async throws {
        // Given
        let pluginPath = try temporaryPath().appending(component: "Plugin")
        let pluginName = "TestPlugin"

        manifestLoader.loadConfigStub = { _ in
            .manifestTest(plugins: [.local(path: .relativeToRoot(pluginPath.pathString))])
        }

        manifestLoader.loadPluginStub = { _ in
            Plugin(name: pluginName)
        }

        let config = mockConfig(plugins: [PluginLocation.local(path: pluginPath)])

        try fileHandler.createFolder(
            pluginPath.appending(component: Constants.helpersDirectoryName)
        )

        // When
        let plugins = try await subject.loadPlugins(using: config)

        // Then
        let expectedHelpersPath = pluginPath.appending(component: Constants.helpersDirectoryName)
        let expectedPlugins = Plugins
            .test(projectDescriptionHelpers: [.init(name: pluginName, path: expectedHelpersPath, location: .local)])
        XCTAssertEqual(plugins, expectedPlugins)
    }

    func test_loadPlugins_WHEN_gitHelpers() async throws {
        // Given
        let pluginGitUrl = "https://url/to/repo.git"
        let pluginGitReference = "1.0.0"
        let pluginFingerprint = "\(pluginGitUrl)-\(pluginGitReference)".md5
        let pluginName = "TestPlugin"
        let lockfileData =
        """
        pluginsMetadata:
        - cachePath: \(mockCachePath.appending(component: pluginFingerprint).pathString)
          hash: \(pluginFingerprint)
          name: \(pluginFingerprint)
          url: \(pluginGitUrl)
        """

        /// create cache folder & lockfile
        try fileHandler.createFolder(mockCachePath)
        try fileHandler.write(lockfileData, path: mockCachePath.appending(component: Constants.Plugins.plugisSandbox), atomically: true)
        try fileHandler.createFolder(mockCachePath.appending(components: [pluginFingerprint, Constants.helpersDirectoryName]))

        manifestLoader.loadConfigStub = { _ in
            .manifestTest(plugins: [ProjectDescription.PluginLocation.git(url: pluginGitUrl, tag: pluginGitReference)])
        }

        manifestLoader.loadPluginStub = { _ in
            Plugin(name: pluginName)
        }

        let config = mockConfig(plugins: [
            PluginLocation.git(
                url: pluginGitUrl,
                tag: pluginGitReference,
                directory: nil
            ),
        ])

        // When
        let plugins = try await subject.loadPlugins(using: config)

        // Then
        let expectedHelpersPath = mockCachePath.appending(components: [pluginFingerprint, Constants.helpersDirectoryName])
        let expectedPlugins = Plugins
            .test(projectDescriptionHelpers: [.init(name: pluginName, path: expectedHelpersPath, location: .remote)])
        XCTAssertEqual(plugins, expectedPlugins)
    }

    func test_loadPlugins_WHEN_localTemplate() async throws {
        // Given
        let pluginPath = try temporaryPath()
        let pluginName = "TestPlugin"
        let templatePath = pluginPath.appending(components: "Templates", "custom")
        templatesDirectoryLocator.templatePluginDirectoriesStub = { _ in
            [
                templatePath,
            ]
        }

        try makeDirectories(templatePath)

        // When
        manifestLoader.loadConfigStub = { _ in
            .manifestTest(plugins: [.local(path: .relativeToRoot(pluginPath.pathString))])
        }

        manifestLoader.loadPluginStub = { _ in
            Plugin(name: pluginName)
        }

        let config = mockConfig(plugins: [PluginLocation.local(path: pluginPath)])

        // Then
        let plugins = try await subject.loadPlugins(using: config)
        let expectedPlugins = Plugins.test(templatePaths: [templatePath])
        XCTAssertEqual(plugins, expectedPlugins)
    }

    func test_loadPlugins_WHEN_gitTemplate() async throws {
        // Given
        let pluginGitUrl = "https://url/to/repo.git"
        let pluginGitReference = "1.0.0"
        let pluginFingerprint = "\(pluginGitUrl)-\(pluginGitReference)".md5
        let cachedPluginPath = mockCachePath.appending(components: pluginFingerprint)
        let pluginName = "TestPlugin"
        let templatePath = cachedPluginPath.appending(components: "Templates", "custom")
        templatesDirectoryLocator.templatePluginDirectoriesStub = { _ in
            [
                templatePath,
            ]
        }
        
        let lockfileData =
        """
        pluginsMetadata:
        - cachePath: \(mockCachePath.appending(component: pluginFingerprint).pathString)
          hash: \(pluginFingerprint)
          name: \(pluginFingerprint)
          url: \(pluginGitUrl)
        """

        /// create cache folder & lockfile
        try fileHandler.createFolder(mockCachePath)
        try fileHandler.write(lockfileData, path: mockCachePath.appending(component: Constants.Plugins.plugisSandbox), atomically: true)
        try fileHandler.createFolder(mockCachePath.appending(components: [pluginFingerprint]))
        try makeDirectories(templatePath)

        // When
        manifestLoader.loadConfigStub = { _ in
            .manifestTest(plugins: [ProjectDescription.PluginLocation.git(url: pluginGitUrl, tag: pluginGitReference)])
        }

        manifestLoader.loadPluginStub = { _ in
            .manifestTest(name: pluginName)
        }

        let config =
            mockConfig(plugins: [
                PluginLocation
                    .git(url: pluginGitUrl, tag: pluginGitReference, directory: nil),
            ])

        // Then
        let plugins = try await subject.loadPlugins(using: config)
        let expectedPlugins = Plugins.test(templatePaths: [templatePath])
        XCTAssertEqual(plugins, expectedPlugins)
    }

    private func mockConfig(plugins: [PluginLocation]) -> GekoGraph.Config {
        Config(
            compatibleXcodeVersions: .all,
            cloud: nil,
            cache: nil,
            swiftVersion: nil,
            plugins: plugins,
            generationOptions: .test(),
            preFetchScripts: [],
            preGenerateScripts: [],
            postGenerateScripts: [],
            cocoapodsUseBundler: false
        )
    }
}
