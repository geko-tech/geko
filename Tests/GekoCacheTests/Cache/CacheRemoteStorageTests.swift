import GekoCacheTesting
import GekoCloud
import GekoCore
import GekoGraph
import GekoGraphTesting
import GekoSupport
import ProjectDescription
import XCTest

@testable import GekoCache
@testable import GekoCacheTesting
@testable import GekoCoreTesting
@testable import GekoSupportTesting
@testable import GekoCloudTesting

final class CacheRemoteStorageTests: GekoUnitTestCase {
    private var subject: CacheRemoteStorage!
    private var cloudConfig: Cloud!
    private var fileArchiverFactory: MockFileArchivingFactory!
    private var fileArchiver: MockFileArchiver!
    private var fileUnarchiver: MockFileUnarchiver!
    private var fileClient: MockFileClient!
    private var zipPath: AbsolutePath!
    private var cacheLatestPathStore: CacheLatestPathStoreMock!
    private var cacheCloudService: CacheCloudServiceMock!
    private var cacheContextFolderProvider: CacheContextFolderProviderMock!
    private var cacheDirectoriesProvider: MockCacheDirectoriesProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        zipPath = fixturePath(path: try RelativePath(validating: "uUI.xcframework.zip"))

        cloudConfig = .test()
        cacheLatestPathStore = CacheLatestPathStoreMock()
        cacheCloudService = CacheCloudServiceMock()
        cacheContextFolderProvider = CacheContextFolderProviderMock()
        cacheContextFolderProvider.stubContextFolderName = "Debug-arm64"
        fileArchiverFactory = MockFileArchivingFactory()
        fileArchiver = MockFileArchiver()
        fileUnarchiver = MockFileUnarchiver()
        fileArchiver.stubbedZipResult = zipPath
        fileArchiverFactory.stubbedMakeFileArchiverResult = fileArchiver
        fileArchiverFactory.stubbedMakeFileUnarchiverResult = fileUnarchiver
        fileClient = MockFileClient()
        fileClient.stubbedDownloadResult = zipPath

        cacheDirectoriesProvider = try MockCacheDirectoriesProvider()
        cacheDirectoriesProvider.cacheDirectoryStub = try temporaryPath()
        
        subject = CacheRemoteStorage(
            cloudUrl: URL(string: cloudConfig.url)!,
            cloudBucket: cloudConfig.bucket,
            fileArchiverFactory: fileArchiverFactory,
            cacheDirectoriesProvider: cacheDirectoriesProvider,
            cacheLatestPathStore: cacheLatestPathStore,
            cacheCloud: cacheCloudService,
            cacheContextFolderProvider: cacheContextFolderProvider
        )
    }

    override func tearDown() {
        subject = nil
        cloudConfig = nil
        fileArchiver = nil
        fileArchiverFactory = nil
        fileClient = nil
        zipPath = nil
        cacheCloudService = nil
        cacheDirectoriesProvider = nil
        cacheLatestPathStore = nil
        cacheContextFolderProvider = nil
        super.tearDown()
    }

    // - exists

    func test_exists_whenArtifactDoesNotExist() async throws {
        // Given
        cacheCloudService.cacheExistsStub = { _, _, _ in
            return false
        }

        // When
        let result = try await subject.exists(name: "targetName", hash: "acho tio")

        // Then
        XCTAssertFalse(result)
    }

    // - fetch

    func test_fetch_whenArchiveContainsIncorrectRootFolderAfterUnzipping_expectErrorThrown() async throws {
        // Given
        let downloadedFile = try temporaryPath().appending(component: "Foo")
        try fileHandler.touch(downloadedFile)
        let hash = "foobar"
        let paths = try createFolders(["Unarchived/\(hash)/IncorrectRootFolderAfterUnzipping"])
        fileUnarchiver.stubbedUnzipResult = paths.first
        cacheCloudService.downloadStub = { _, _, _ in
            return downloadedFile
        }

        // When / Then
        await XCTAssertThrowsSpecific(
            try await subject.fetch(name: "targetName", hash: hash),
            CacheRemoteStorageError.artifactNotFound(hash: hash)
        )
    }

    func test_fetch_whenClientReturnsASuccess_returnsCorrectRootFolderAfterUnzipping() async throws {
        // Given
        let hash = "bar_foo"
        let targetName = "targetName"
        let folder = "Unarchived/\(targetName)/\(cacheContextFolderProvider.contextFolderName())/\(hash)/myFramework.xcframework"
        let paths = try createFolders([folder])
        fileUnarchiver.stubbedUnzipResult = paths.first?.removingLastComponent().removingLastComponent()
        let downloadedFile = try temporaryPath().appending(component: "Foo")
        try fileHandler.touch(downloadedFile)
        cacheCloudService.downloadStub = { _, _, _ in
            return downloadedFile
        }

        // When
        let result = try await subject.fetch(name: targetName, hash: hash)

        // Then
        let expectedPath = cacheDirectoriesProvider.cacheDirectory(for: .builds)
            .appending(try RelativePath(validating: "\(targetName)/\(cacheContextFolderProvider.contextFolderName())/\(hash)/myFramework.xcframework"))
        XCTAssertEqual(result, expectedPath)
    }

    func test_fetch_whenClientReturnsASuccess_givesCorrectDownloadParams() async throws {
        // Given
        let contextFolder = "Debug-arm64"
        let hash = "bar_foo"
        let targetName = "targetName"
        let folder = "Unarchived/\(targetName)/\(cacheContextFolderProvider.contextFolderName())/\(hash)/myFramework.xcframework"
        let paths = try createFolders([folder])
        fileUnarchiver.stubbedUnzipResult = paths.first?.removingLastComponent().removingLastComponent()
        let downloadedFile = try temporaryPath().appending(component: "Foo")
        try fileHandler.touch(downloadedFile)
        
        cacheCloudService.downloadStub = { expectedHash, expectedName, expectedFolderContext in
            // Then
            XCTAssertEqual(expectedHash, hash)
            XCTAssertEqual(expectedName, targetName)
            XCTAssertEqual(expectedFolderContext, contextFolder)
            return downloadedFile
        }

        // When
        _ = try await subject.fetch(name: targetName, hash: hash)
    }

    func test_fetch_whenClientReturnsASuccess_givesFileArchiverTheCorrectDestinationPath() async throws {
        // Given
        let hash = "bar_foo"
        let targetName = "targetName"
        let folder = "Unarchived/\(targetName)/\(cacheContextFolderProvider.contextFolderName())/\(hash)/myFramework.xcframework"
        let paths = try createFolders([folder])
        fileUnarchiver.stubbedUnzipResult = paths.first?.removingLastComponent().removingLastComponent()
        let downloadedFile = try temporaryPath().appending(component: "Foo")
        try fileHandler.touch(downloadedFile)
        cacheCloudService.downloadStub = { _, _, _ in
            return downloadedFile
        }
        
        // When
        _ = try await subject.fetch(name: targetName, hash: hash)

        // Then
        XCTAssertTrue(fileUnarchiver.invokedUnzip)
    }

    // - store

    func test_store_whenClientReturnsASuccess() async throws {
        // Given
        let name = "targetName"
        let hash = "bar_foo"
        
        // When
        try await subject.store(name: name, hash: hash, paths: [.root])
        
        // Then
        let expected = cacheDirectoriesProvider.cacheDirectory(for: .builds)
            .appending(try RelativePath(validating: "\(name)/\(cacheContextFolderProvider.contextFolderName())/\(hash)"))

        XCTAssertEqual(cacheLatestPathStore.invokedStoreParamters, expected)
    }
}
