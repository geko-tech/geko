import ProjectDescription
import GekoCore
import GekoGraph
import GekoSupport
import XCTest
@testable import GekoSupportTesting

final class SwiftPackageManagerControllerTests: GekoUnitTestCase {
    private var subject: SwiftPackageManagerController!

    override func setUp() {
        super.setUp()

        subject = SwiftPackageManagerController()
    }

    override func tearDown() {
        subject = nil

        super.tearDown()
    }

    func test_resolve() throws {
        // Given
        let path = try temporaryPath()
        system.succeedCommand([
            "swift",
            "package",
            "--package-path",
            path.pathString,
            "resolve",
        ])

        // When / Then
        XCTAssertNoThrow(try subject.resolve(at: path, arguments: [], printOutput: false))
    }

    func test_update() throws {
        // Given
        let path = try temporaryPath()
        system.succeedCommand([
            "swift",
            "package",
            "--package-path",
            path.pathString,
            "update",
        ])

        // When / Then
        XCTAssertNoThrow(try subject.update(at: path, arguments: [], printOutput: false))
    }

    func test_setToolsVersion_specificVersion() throws {
        // Given
        let path = try temporaryPath()
        let version = Version("5.4.0")
        system.succeedCommand([
            "swift",
            "package",
            "--package-path",
            path.pathString,
            "tools-version",
            "--set",
            "5.4",
        ])

        // When / Then
        XCTAssertNoThrow(try subject.setToolsVersion(at: path, to: version))
    }

    func test_loadPackageInfo() throws {
        // Given
        let path = try temporaryPath()
        system.succeedCommand(
            [
                "swift",
                "package",
                "--package-path",
                path.pathString,
                "dump-package",
            ],
            output: PackageInfo.testJSON
        )

        // When
        let packageInfo = try subject.loadPackageInfo(at: path)

        // Then
        XCTAssertEqual(packageInfo, PackageInfo.test)
    }

    func test_loadPackageInfo_Xcode14() throws {
        // Given
        let path = try temporaryPath()
        system.succeedCommand(
            [
                "swift",
                "package",
                "--package-path",
                path.pathString,
                "dump-package",
            ],
            output: PackageInfo.testJSONXcode14
        )

        // When
        let packageInfo = try subject.loadPackageInfo(at: path)

        // Then
        XCTAssertEqual(packageInfo, PackageInfo.test)
    }

    // swiftlint:disable:next function_body_length
    func test_loadPackageInfo_withTraits() throws {
        let path = try temporaryPath()
        system.succeedCommand(
            [
                "swift",
                "package",
                "--package-path",
                path.pathString,
                "dump-package",
            ],
            output: """
            {
              "name": "Root",
              "products": [],
              "targets": [
                {
                  "name": "Root",
                  "path": null,
                  "url": null,
                  "sources": null,
                  "packageAccess": false,
                  "resources": [],
                  "exclude": [],
                  "dependencies": [
                    {
                      "target": [
                        "Child",
                        {
                          "platformNames": [],
                          "config": null,
                          "traits": ["Feature"]
                        }
                      ]
                    }
                  ],
                  "publicHeadersPath": null,
                  "type": "regular",
                  "settings": [],
                  "checksum": null
                }
              ],
              "traits": [
                {
                  "enabledTraits": ["Feature"],
                  "name": "default",
                  "description": null
                },
                {
                  "enabledTraits": [],
                  "name": "Feature",
                  "description": "Feature flag"
                }
              ],
              "dependencies": [
                {
                  "sourceControl": [
                    {
                      "identity": "child",
                      "traits": [
                        {
                          "name": "default"
                        }
                      ]
                    }
                  ]
                }
              ],
              "platforms": [],
              "cLanguageStandard": null,
              "cxxLanguageStandard": null,
              "swiftLanguageVersions": null,
              "toolsVersion": {
                "_version": "6.2.0"
              }
            }
            """
        )

        let packageInfo = try subject.loadPackageInfo(at: path)

        XCTAssertEqual(packageInfo.traits, [
            PackageTrait(enabledTraits: ["Feature"], name: "default", description: nil),
            PackageTrait(enabledTraits: [], name: "Feature", description: "Feature flag"),
        ])
        XCTAssertEqual(packageInfo.dependencies, [
            PackageDependency(identity: "child", traits: [PackageDependencyTrait(name: "default")]),
        ])
        guard case let .target(_, condition) = packageInfo.targets[0].dependencies[0] else {
            return XCTFail("Expected target dependency")
        }
        XCTAssertEqual(condition?.traits, ["Feature"])
    }

    func test_loadPackageInfo_alamofire() throws {
        // Given
        let path = try temporaryPath()
        system.succeedCommand(
            [
                "swift",
                "package",
                "--package-path",
                path.pathString,
                "dump-package",
            ],
            output: PackageInfo.alamofireJSON
        )

        // When
        let packageInfo = try subject.loadPackageInfo(at: path)

        // Then
        XCTAssertEqual(packageInfo, PackageInfo.alamofire)
    }

    func test_loadPackageInfo_googleAppMeasurement() throws {
        // Given
        let path = try temporaryPath()
        system.succeedCommand(
            [
                "swift",
                "package",
                "--package-path",
                path.pathString,
                "dump-package",
            ],
            output: PackageInfo.googleAppMeasurementJSON
        )

        // When
        let packageInfo = try subject.loadPackageInfo(at: path)

        // Then
        XCTAssertEqual(packageInfo, PackageInfo.googleAppMeasurement)
    }

    func test_buildFatReleaseBinary() throws {
        // Given
        let packagePath = try temporaryPath()
        let product = "my-product"
        let buildPath = try temporaryPath()
        let outputPath = try temporaryPath()

        system.succeedCommand([
            "swift", "build",
            "--configuration", "release",
            "--disable-sandbox",
            "--package-path", packagePath.pathString,
            "--product", product,
            "--build-path", buildPath.pathString,
            "--triple", "arm64-apple-macosx",
        ])
        system.succeedCommand([
            "swift", "build",
            "--configuration", "release",
            "--disable-sandbox",
            "--package-path", packagePath.pathString,
            "--product", product,
            "--build-path", buildPath.pathString,
            "--triple", "x86_64-apple-macosx",
        ])

        system.succeedCommand([
            "lipo", "-create", "-output", outputPath.appending(component: product).pathString,
            buildPath.appending(components: "arm64-apple-macosx", "release", product).pathString,
            buildPath.appending(components: "x86_64-apple-macosx", "release", product).pathString,
        ])

        // When
        try subject.buildFatReleaseBinary(
            packagePath: packagePath,
            product: product,
            buildPath: buildPath,
            outputPath: outputPath
        )

        // Then
        // Assert that `outputPath` was created
        XCTAssertTrue(fileHandler.isFolder(outputPath))
    }
}
