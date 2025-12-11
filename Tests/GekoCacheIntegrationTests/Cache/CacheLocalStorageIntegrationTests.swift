import Foundation
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import GekoCore
import GekoSupport
import XCTest
@testable import GekoCache
@testable import GekoCoreTesting
@testable import GekoSupportTesting
@testable import GekoCacheTesting

final class CacheLocalStorageIntegrationTests: GekoTestCase {
    var subject: CacheLocalStorage!
    var cacheContextFolderProvider: CacheContextFolderProviderMock!

    override func setUp() {
        super.setUp()
        let cacheDirectory = try! temporaryPath()
        cacheContextFolderProvider = CacheContextFolderProviderMock()
        cacheContextFolderProvider.stubContextFolderName = "Test"
        subject = CacheLocalStorage(cacheDirectory: cacheDirectory, cacheContextFolderProvider: cacheContextFolderProvider)
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_exists_when_a_cached_xcframework_exists() async throws {
        // Given
        let cacheDirectory = try temporaryPath()
        let hash = "abcde"
        let moduleName = "ignored"
        let moduleDirectory = cacheDirectory.appending(component: moduleName)
        let contextDirectory = moduleDirectory.appending(component: cacheContextFolderProvider.contextFolderName())
        let hashDirectory = contextDirectory.appending(component: hash)
        let xcframeworkPath = hashDirectory.appending(component: "framework.xcframework")
        try FileHandler.shared.createFolder(moduleDirectory)
        try FileHandler.shared.createFolder(contextDirectory)
        try FileHandler.shared.createFolder(hashDirectory)
        try FileHandler.shared.createFolder(xcframeworkPath)

        // When
        let got = try subject.exists(name: moduleName, hash: hash)

        // Then
        XCTAssertTrue(got == true)
    }

    func test_exists_when_a_cached_xcframework_does_not_exist() async throws {
        // When
        let hash = "abcde"

        let got = try subject.exists(name: "ignored", hash: hash)

        // Then
        XCTAssertTrue(got == false)
    }

    func test_fetch_when_a_cached_xcframework_exists() async throws {
        // Given
        let cacheDirectory = try temporaryPath()
        let hash = "abcde"
        let moduleName = "ignored"
        let moduleDirectory = cacheDirectory.appending(component: moduleName)
        let contextDirectory = moduleDirectory.appending(component: cacheContextFolderProvider.contextFolderName())
        let hashDirectory = contextDirectory.appending(component: hash)
        let xcframeworkPath = hashDirectory.appending(component: "framework.xcframework")
        try FileHandler.shared.createFolder(moduleDirectory)
        try FileHandler.shared.createFolder(contextDirectory)
        try FileHandler.shared.createFolder(hashDirectory)
        try FileHandler.shared.createFolder(xcframeworkPath)

        // When
        let got = try subject.fetch(name: moduleName, hash: hash)

        // Then
        XCTAssertTrue(got == xcframeworkPath)
    }

    func test_fetch_when_a_cached_xcframework_does_not_exist() async throws {
        let hash = "abcde"

        await XCTAssertThrowsSpecific(
            try subject.fetch(name: "ignored", hash: hash),
            CacheLocalStorageError.compiledArtifactNotFound(hash: hash)
        )
    }

    func test_store() async throws {
        // Given
        let hash = "abcde"
        let moduleName = "ignored"
        let cacheDirectory = try temporaryPath()
        let xcframeworkPath = cacheDirectory.appending(component: "framework.xcframework")
        try FileHandler.shared.createFolder(xcframeworkPath)

        // When
        _ = try subject.store(name: moduleName, hash: hash, paths: [xcframeworkPath])

        // Then
        XCTAssertTrue(
            FileHandler.shared
                .exists(cacheDirectory.appending(try RelativePath(validating: "\(moduleName)/\(cacheContextFolderProvider.contextFolderName())/\(hash)/framework.xcframework")))
        )
    }
}
