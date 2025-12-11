import Foundation
import GekoCore
import GekoCoreTesting
import GekoSupport
import XCTest

@testable import GekoKit
@testable import GekoSupportTesting

final class CleanServiceTests: GekoUnitTestCase {
    private var subject: CleanService!
    private var cacheDirectoriesProvider: MockCacheDirectoriesProvider!
    private var logDirectoriesProvider: MockLogDirectoriesProvider!

    override func setUp() {
        super.setUp()
        let mockCacheDirectoriesProvider = try! MockCacheDirectoriesProvider()
        cacheDirectoriesProvider = mockCacheDirectoriesProvider
        logDirectoriesProvider = try! MockLogDirectoriesProvider()

        subject = CleanService(
            cacheDirectoryProviderFactory: MockCacheDirectoriesProviderFactory(provider: mockCacheDirectoriesProvider),
            logDirectoriesProvider: logDirectoriesProvider
        )
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }
    
    func test_run_without_category_cleans() throws {
        // Given
        let cachePaths = try createFolders(["Cache", "Cache/Manifests"])
        let cachePath = cachePaths[0]
        for path in cachePaths {
            let correctlyCreated = FileManager.default.fileExists(atPath: path.pathString)
            XCTAssertTrue(correctlyCreated, "Test setup is not properly done. Folder \(path.pathString) should exist")
        }
        cacheDirectoriesProvider.cacheDirectoryStub = cachePath
        let buildCachePath = cachePaths[1]
        
        let oldFolder = buildCachePath.appending(component: "OldFolder")
        try fileHandler.createFolder(oldFolder)
        let modifyDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -8, to: Date()))
        try fileHandler.fileUpdateAccessDate(path: oldFolder, date: modifyDate)

        let newFolder = buildCachePath.appending(component: "NewFolder")
        try fileHandler.createFolder(newFolder)
        
        // When
        try subject.run(categories: CleanCategory.allCases, path: nil, full: false)
        
        // Then
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: oldFolder.pathString),
            "File at path \(oldFolder) should have been deleted by the test."
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: newFolder.pathString),
            "File at path \(newFolder) should not have been deleted by the test."
        )
    }

    func test_run_with_category_cleans_category_full_mode() throws {
        // Given
        let cachePaths = try createFolders(["Cache", "Cache/BuildCache", "Cache/Manifests", "Cache/incremental-tests"])
        let cachePath = cachePaths[0]
        for path in cachePaths {
            let correctlyCreated = FileManager.default.fileExists(atPath: path.pathString)
            XCTAssertTrue(correctlyCreated, "Test setup is not properly done. Folder \(path.pathString) should exist")
        }
        cacheDirectoriesProvider.cacheDirectoryStub = cachePath

        // When
        try subject.run(categories: [.global(.builds), .global(.tests)], path: nil, full: true)

        // Then
        let buildsExists = FileManager.default.fileExists(atPath: cachePaths[1].pathString)
        XCTAssertFalse(buildsExists, "Cache folder at path \(cachePaths[1]) should have been deleted by the test.")
        let manifestsExists = FileManager.default.fileExists(atPath: cachePaths[2].pathString)
        XCTAssertTrue(
            manifestsExists,
            "Cache folder at path \(cachePaths[2].pathString) should not have been deleted by the test."
        )
        let testsExists = FileManager.default.fileExists(atPath: cachePaths[3].pathString)
        XCTAssertFalse(testsExists, "Cache folder at path \(cachePaths[3].pathString) should not have been deleted by the test.")
    }

    func test_run_without_category_cleans_full_mode() throws {
        // Given
        let cachePaths = try createFolders(["Cache", "Cache/Plugins", "Cache/Projects", "Cache/ProjectDescriptionHelpers", "Cache/BuildCache", "Cache/Manifests", "Cache/incremental-tests"])
        let cachePath = cachePaths[0]
        for path in cachePaths {
            let correctlyCreated = FileManager.default.fileExists(atPath: path.pathString)
            XCTAssertTrue(correctlyCreated, "Test setup is not properly done. Folder \(path.pathString) should exist")
        }
        cacheDirectoriesProvider.cacheDirectoryStub = cachePath

        let projectPath = try temporaryPath()
        let dependenciesPath = projectPath.appending(
            components: Constants.gekoDirectoryName, Constants.DependenciesDirectory.name
        )
        let spmDependenciesPath = projectPath.appending(
            components: Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            Constants.DependenciesDirectory.swiftPackageManagerDirectoryName
        )
        let cocoapodsDependenciesPath = projectPath.appending(components: [
            Constants.gekoDirectoryName,
            Constants.DependenciesDirectory.name,
            "Cocoapods"
        ])
        try fileHandler.createFolder(dependenciesPath)
        try fileHandler.createFolder(spmDependenciesPath)
        
        let logsPath = projectPath.appending(component: ".geko")
        logDirectoriesProvider.logDirectoryStub = logsPath
        let buildLogsPath = logsPath.appending(component: "BuildLogs")
        let analyticsLogsPath = logsPath.appending(component: "Analytics")
        let hashesLogsPath = logsPath.appending(component: "CacheHashes")
        let inspectLogsPath = logsPath.appending(component: "Inspect")
        
        try fileHandler.createFolder(logsPath)
        try fileHandler.createFolder(buildLogsPath)
        try fileHandler.createFolder(analyticsLogsPath)
        try fileHandler.createFolder(hashesLogsPath)
        try fileHandler.createFolder(inspectLogsPath)
        
        // When
        try subject.run(categories: CleanCategory.allCases, path: nil, full: true)
        
        // Then
        let pluginExists = FileManager.default.fileExists(atPath: cachePaths[1].pathString)
        XCTAssertFalse(pluginExists, "Cache folder at path \(cachePaths[1]) should have been deleted by the test.")
        let projectExists = FileManager.default.fileExists(atPath: cachePaths[2].pathString)
        XCTAssertFalse(projectExists, "Cache folder at path \(cachePaths[2]) should have been deleted by the test.")
        let helpersExists = FileManager.default.fileExists(atPath: cachePaths[3].pathString)
        XCTAssertFalse(helpersExists, "Cache folder at path \(cachePaths[3]) should have been deleted by the test.")
        let buildCacheExists = FileManager.default.fileExists(atPath: cachePaths[4].pathString)
        XCTAssertFalse(buildCacheExists, "Cache folder at path \(cachePaths[4]) should have been deleted by the test.")
        let manifestsExists = FileManager.default.fileExists(atPath: cachePaths[5].pathString)
        XCTAssertFalse(manifestsExists, "Cache folder at path \(cachePaths[5]) should have been deleted by the test.")
        let testsExists = FileManager.default.fileExists(atPath: cachePaths[6].pathString)
        XCTAssertFalse(testsExists, "Cache folder at path \(cachePaths[6]) should have been deleted by the test.")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: spmDependenciesPath.pathString),
            "Cache folder at path \(spmDependenciesPath) should have been deleted by the test."
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: cocoapodsDependenciesPath.pathString),
            "Cache folder at path \(cocoapodsDependenciesPath) should have been deleted by the test."
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: buildLogsPath.pathString),
            "Cache folder at path \(buildLogsPath) should have been deleted by the test."
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: analyticsLogsPath.pathString),
            "Cache folder at path \(analyticsLogsPath) should have been deleted by the test."
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: hashesLogsPath.pathString),
            "Cache folder at path \(hashesLogsPath) should have been deleted by the test."
        )
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: inspectLogsPath.pathString),
            "Cache folder at path \(inspectLogsPath) should have been deleted by the test."
        )
    }
}
