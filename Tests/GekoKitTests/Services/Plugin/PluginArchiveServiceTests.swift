import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.Plugin
import GekoSupport
import GekoSupportTesting
import XCTest
@testable import GekoCoreTesting

import GekoLoaderTesting
@testable import GekoKit

final class PluginArchiveServiceTests: GekoUnitTestCase {
    private var subject: PluginArchiveService!
    private var swiftPackageManagerController: MockSwiftPackageManagerController!
    private var xcodebuildController: MockXcodeBuildController!
    private var manifestLoader: MockManifestLoader!
    private var fileArchiverFactory: MockFileArchivingFactory!

    override func setUp() {
        super.setUp()
        swiftPackageManagerController = MockSwiftPackageManagerController()
        xcodebuildController = MockXcodeBuildController()
        manifestLoader = MockManifestLoader()
        fileArchiverFactory = MockFileArchivingFactory()
        subject = PluginArchiveService(
            swiftPackageManagerController: swiftPackageManagerController,
            xcodebuildController: xcodebuildController,
            manifestLoader: manifestLoader,
            fileArchiverFactory: fileArchiverFactory
        )
    }

    override func tearDown() {
        subject = nil
        swiftPackageManagerController = nil
        xcodebuildController = nil
        manifestLoader = nil
        fileArchiverFactory = nil
        super.tearDown()
    }

    func test_run_with_no_output_path_and_create_zip() throws {
#if os(Linux)
        throw XCTSkip()
#endif
        // Given
        let path = try temporaryPath()
        var invokedPackagePath: AbsolutePath?
        var builtProducts: [String] = []
        let fileArchiver = MockFileArchiver()
        try given(
            path: path,
            fileArchiver: fileArchiver,
            invokedPackagePath: { invokedPackagePath = $0 },
            builtProducts: { builtProducts.append($0) }
        )

        // When
        try subject.run(path: path.pathString, outputPath: nil, configuration: .release, createZip: true)

        // Then
        XCTAssertEqual(invokedPackagePath, path)
        XCTAssertEqual(builtProducts, ["geko-one", "geko-two"])
        XCTAssertEqual(fileArchiver.invokedZipParameters?.name, "TestPlugin.macos.geko-plugin.zip")
        XCTAssertTrue(fileHandler.isFolder(path.appending(component: "TestPlugin.macos.geko-plugin.zip")))
    }

    func test_run_with_output_path_and_create_zip() throws {
#if os(Linux)
        throw XCTSkip()
#endif
        // Given
        let path = try temporaryPath()
        let outputPath = path.appending(component: "Output")
        var invokedPackagePath: AbsolutePath?
        var builtProducts: [String] = []
        let fileArchiver = MockFileArchiver()
        try given(
            path: path,
            fileArchiver: fileArchiver,
            invokedPackagePath: { invokedPackagePath = $0 },
            builtProducts: { builtProducts.append($0) }
        )

        // When
        try subject.run(path: path.pathString, outputPath: outputPath.pathString, configuration: .release, createZip: true)

        // Then
        XCTAssertEqual(invokedPackagePath, path)
        XCTAssertEqual(builtProducts, ["geko-one", "geko-two"])
        XCTAssertEqual(fileArchiver.invokedZipParameters?.name, "TestPlugin.macos.geko-plugin.zip")
        XCTAssertTrue(fileHandler.isFolder(outputPath.appending(component: "TestPlugin.macos.geko-plugin.zip")))
    }

    func test_run_with_no_output_path_and_no_create_zip() throws {
#if os(Linux)
        throw XCTSkip()
#endif
        // Given
        let path = try temporaryPath()
        var invokedPackagePath: AbsolutePath?
        var builtProducts: [String] = []
        let fileArchiver = MockFileArchiver()
        try given(
            path: path,
            fileArchiver: fileArchiver,
            invokedPackagePath: { invokedPackagePath = $0 },
            builtProducts: { builtProducts.append($0) }
        )

        // When
        try subject.run(path: path.pathString, outputPath: nil, configuration: .release, createZip: false)

        // Then
        XCTAssertEqual(invokedPackagePath, path)
        XCTAssertEqual(builtProducts, ["geko-one", "geko-two"])
        XCTAssertFalse(fileArchiver.invokedZip)

        XCTAssertTrue(fileHandler.exists(path.appending(component: "Plugin.swift")))

        XCTAssertTrue(fileHandler.isFolder(path.appending(component: "PluginBuild")))
        XCTAssertTrue(fileHandler.exists(path.appending(components: ["PluginBuild", "Plugin.swift"])))
        XCTAssertTrue(fileHandler.exists(path.appending(components: ["PluginBuild", "Executables", "geko-one"])))
        XCTAssertTrue(fileHandler.exists(path.appending(components: ["PluginBuild", "Executables", "geko-two"])))

        XCTAssertFalse(fileHandler.exists(path.appending(components: ["PluginBuild", "Executables", "geko-three"])))
        XCTAssertFalse(fileHandler.exists(path.appending(components: ["PluginBuild", "Executables", "my-non-task-executable"])))
    }

    func test_run_with_output_path_and_no_create_zip() throws {
#if os(Linux)
        throw XCTSkip()
#endif
        // Given
        let path = try temporaryPath()
        let outputPath = path.appending(component: "Output")
        var invokedPackagePath: AbsolutePath?
        var builtProducts: [String] = []
        let fileArchiver = MockFileArchiver()
        try given(
            path: path,
            fileArchiver: fileArchiver,
            invokedPackagePath: { invokedPackagePath = $0 },
            builtProducts: { builtProducts.append($0) }
        )

        // When
        try subject.run(path: path.pathString, outputPath: outputPath.pathString, configuration: .release, createZip: false)

        // Then
        XCTAssertEqual(invokedPackagePath, path)
        XCTAssertEqual(builtProducts, ["geko-one", "geko-two"])
        XCTAssertFalse(fileArchiver.invokedZip)

        XCTAssertTrue(fileHandler.exists(path.appending(component: "Plugin.swift")))
        XCTAssertFalse(fileHandler.exists(path.appending(components: ["PluginBuild", "Executables", "geko-three"])))
        XCTAssertFalse(fileHandler.exists(path.appending(components: ["PluginBuild", "Executables", "my-non-task-executable"])))

        XCTAssertTrue(fileHandler.exists(outputPath.appending(component: "Plugin.swift")))
        XCTAssertTrue(fileHandler.exists(outputPath.appending(components: ["Executables", "geko-one"])))
        XCTAssertTrue(fileHandler.exists(outputPath.appending(components: ["Executables", "geko-two"])))

        XCTAssertFalse(fileHandler.exists(outputPath.appending(components: ["Executables", "geko-three"])))
        XCTAssertFalse(fileHandler.exists(outputPath.appending(components: ["Executables", "my-non-task-executable"])))
    }
}

private extension PluginArchiveServiceTests {
    func given(path: AbsolutePath,
               fileArchiver: MockFileArchiver,
               invokedPackagePath: @escaping (AbsolutePath?) -> Void,
               builtProducts: @escaping (String) -> Void
    ) throws -> () {

        swiftPackageManagerController.loadPackageInfoStub = { packagePath in
            invokedPackagePath(packagePath)
            return PackageInfo.test(
                products: [
                    PackageInfo.Product(
                        name: "my-non-task-executable",
                        type: .executable,
                        targets: []
                    ),
                    PackageInfo.Product(
                        name: "geko-one",
                        type: .executable,
                        targets: []
                    ),
                    PackageInfo.Product(
                        name: "geko-two",
                        type: .executable,
                        targets: []
                    ),
                    PackageInfo.Product(
                        name: "geko-three",
                        type: .library(.automatic),
                        targets: []
                    ),
                ]
            )
        }
        manifestLoader.loadPluginStub = { _ in
            Plugin(name: "TestPlugin",
                   executables: [
                    .init(name: "geko-one"),
                    .init(name: "geko-two"),
                   ])
        }

#if os(macOS)
        swiftPackageManagerController.loadBuildFatReleaseBinaryStub = { _, product, _, _ in
            builtProducts(product)
        }
#endif

        fileArchiverFactory.stubbedMakeFileArchiverResult = fileArchiver
        let zipPath = path.appending(components: "test-zip")
        fileArchiver.stubbedZipResult = zipPath
        try fileHandler.createFolder(zipPath)
        try fileHandler.createFolder(path.appending(components: ["artifacts", "geko-one"]))
        try fileHandler.createFolder(path.appending(components: ["artifacts", "geko-two"]))
        try fileHandler.createFolder(path.appending(component: "Package.swift"))
        try fileHandler.createFolder(path.appending(component: "Plugin.swift"))
    }
}
