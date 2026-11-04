import Foundation
import GekoCacheTesting
import GekoCore
import GekoCoreTesting
import GekoSupport
import ProjectDescription
import XCTest
@testable import GekoCache
@testable import GekoSupportTesting

final class BuildableFoldersContentHasherTests: GekoUnitTestCase {
    private var subject: BuildableFoldersContentHasher!
    private var mockContentHasher: MockContentHasher!

    override func setUp() {
        super.setUp()
        mockContentHasher = MockContentHasher()
        subject = BuildableFoldersContentHasher(
            contentHasher: mockContentHasher,
            fileHandler: fileHandler
        )
    }

    override func tearDown() {
        subject = nil
        mockContentHasher = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_hash_includesOnlyNonExceptionFiles() throws {
        // Given
        let folderPath = try AbsolutePath(validating: "/repo/App")
        let sourcePath = try AbsolutePath(validating: "/repo/App/Sources/App.swift")
        let generatedPath = try AbsolutePath(validating: "/repo/App/Generated/File.swift")

        fileHandler.stubFilesAndDirectoriesContained = { _ in [sourcePath, generatedPath] }
        mockContentHasher.stubHashForPath[sourcePath] = "app-source-hash"
        mockContentHasher.stubHashForPath[generatedPath] = "generated-hash"
        mockContentHasher.stubHashForPathWithExclude[folderPath] = "folder-hash"

        let folder = BuildableFolder("/repo/App", exceptions: ["/repo/App/Generated"])

        // When
        let result = try subject.hash(buildableFolders: [folder])

        // Then
        XCTAssertEqual(result.buildableFolderHashes["/repo/App"], "folder-hash")
        XCTAssertEqual(Set(result.sourceHashes.values), ["app-source-hash"])
        XCTAssertFalse(result.sourceHashes.values.contains("generated-hash"))
        XCTAssertEqual(mockContentHasher.hashPathCallCount, 1)
    }

    func test_hash_excludesFileException() throws {
        // Given
        let folderPath = try AbsolutePath(validating: "/repo/App")
        let sourcePath = try AbsolutePath(validating: "/repo/App/Sources/App.swift")
        let excludedPath = try AbsolutePath(validating: "/repo/App/Sources/Excluded.swift")

        fileHandler.stubFilesAndDirectoriesContained = { _ in [sourcePath, excludedPath] }
        mockContentHasher.stubHashForPath[sourcePath] = "app-hash"
        mockContentHasher.stubHashForPath[excludedPath] = "excluded-hash"
        mockContentHasher.stubHashForPathWithExclude[folderPath] = "folder-hash"

        let folder = BuildableFolder("/repo/App", exceptions: ["/repo/App/Sources/Excluded.swift"])

        // When
        let result = try subject.hash(buildableFolders: [folder])

        // Then
        XCTAssertEqual(result.buildableFolderHashes["/repo/App"], "folder-hash")
        XCTAssertEqual(Set(result.sourceHashes.values), ["app-hash"])
        XCTAssertFalse(result.sourceHashes.values.contains("excluded-hash"))
        XCTAssertEqual(mockContentHasher.hashPathCallCount, 1)
    }

    func test_hash_withoutExceptions_includesAllFiles() throws {
        // Given
        let folderPath = try AbsolutePath(validating: "/repo/App")
        let firstPath = try AbsolutePath(validating: "/repo/App/Sources/App.swift")
        let secondPath = try AbsolutePath(validating: "/repo/App/Sources/Feature.swift")

        fileHandler.stubFilesAndDirectoriesContained = { _ in [firstPath, secondPath] }
        mockContentHasher.stubHashForPath[firstPath] = "app-hash"
        mockContentHasher.stubHashForPath[secondPath] = "feature-hash"
        mockContentHasher.stubHashForPathWithExclude[folderPath] = "folder-hash"

        let folder = BuildableFolder("/repo/App", exceptions: [])

        // When
        let result = try subject.hash(buildableFolders: [folder])

        // Then
        XCTAssertEqual(Set(result.sourceHashes.values), ["app-hash", "feature-hash"])
        XCTAssertEqual(result.buildableFolderHashes["/repo/App"], "folder-hash")
        XCTAssertEqual(mockContentHasher.hashPathCallCount, 2)
    }

    func test_hash_multipleFolders_combinesSortedFolderHashes() throws {
        // Given
        let appFolderPath = try AbsolutePath(validating: "/repo/App")
        let featureFolderPath = try AbsolutePath(validating: "/repo/Modules/FeatureA")
        let appSourcePath = try AbsolutePath(validating: "/repo/App/Sources/App.swift")
        let featureSourcePath = try AbsolutePath(validating: "/repo/Modules/FeatureA/Sources/FeatureA.swift")

        fileHandler.stubFilesAndDirectoriesContained = { path in
            path == appFolderPath ? [appSourcePath] : [featureSourcePath]
        }
        mockContentHasher.stubHashForPath[appSourcePath] = "app-hash"
        mockContentHasher.stubHashForPath[featureSourcePath] = "feature-hash"
        mockContentHasher.stubHashForPathWithExclude[appFolderPath] = "app-folder-hash"
        mockContentHasher.stubHashForPathWithExclude[featureFolderPath] = "feature-folder-hash"

        let folders = [
            BuildableFolder("/repo/App", exceptions: []),
            BuildableFolder("/repo/Modules/FeatureA", exceptions: []),
        ]

        // When
        let result = try subject.hash(buildableFolders: folders)

        // Then
        XCTAssertEqual(result.buildableFolderHashes["/repo/App"], "app-folder-hash")
        XCTAssertEqual(result.buildableFolderHashes["/repo/Modules/FeatureA"], "feature-folder-hash")
        XCTAssertEqual(result.hash, "app-folder-hash;feature-folder-hash")
        XCTAssertEqual(Set(result.sourceHashes.values), ["feature-hash"])
    }

    func test_hash_emptyFolders_returnsEmptyHash() throws {
        // When
        let result = try subject.hash(buildableFolders: [])

        // Then
        XCTAssertEqual(result.hash, "")
        XCTAssertTrue(result.buildableFolderHashes.isEmpty)
        XCTAssertTrue(result.sourceHashes.isEmpty)
    }
}